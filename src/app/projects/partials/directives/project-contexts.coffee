angular.module('doubtfire.projects.partials.contexts', ['doubtfire.tasks'])

.directive('progressInfo', ->
  restrict: 'E'
  templateUrl: 'projects/partials/templates/progress-info.tpl.html'
  controller: ($scope, $state, $stateParams, Project, Unit, UnitRole, headerService, alertService, gradeService, taskService) ->
    $scope.studentProjectId = $stateParams.projectId
    $scope.grades = gradeService.grades

    $scope.chooseGrade = (idx) ->
      Project.update { id: $scope.project.project_id, target_grade: idx }, (project) ->
        $scope.project.target_grade = project.target_grade
        $scope.burndownData = project.burndown_chart_data

    $scope.xAxisTickFormat_Date_Format = () ->
      (d) -> d3.time.format('%b %d')(new Date(d * 1000))

    $scope.yAxisTickFormat_Percent_Format = () ->
      (d) -> d3.format(',%')(d)

    $scope.colorFunction = () ->
      (d, i) ->
        if i == 0 #projeted
          '#AAAAAA'
        else if i == 1 #target
          '#777777'
        else if i == 2 #done
          '#0079d8'
        else #sign off
          '#E01B5D'

    #
    # Clips x values to be at the y = 0 intercept if y < 0
    #
    $scope.xAxisClipNegBurndown = () ->
      (d) ->
        if d[1] < 0.0
          # find the x intercept at y = 0
          # know originX is the origin date of the graph (i.e. burnoff is still 100%)
          originX = $scope.burndownData[0].values[0][0]
          # work off the 100% point and this point
          [pt1x, pt1y] = [originX, 1]
          [pt2x, pt2y] = [d[0], d[1]]
          # find gradient
          m    = (pt2y - pt1y) / (pt2x - pt1x)
          # get actual y intercept
          c    = pt1y - m * pt1x
          # solve x intercept via 0 = mx+c
          -c/m
        else
          d[0]

    #
    # Clips y to 0 if y < 0
    #
    $scope.yAxisClipNegBurndown = () ->
      (d) ->
        if d[1] < 0.0 then 0 else d[1]

    $scope.updateBurndownChart = () ->
      # $scope.burndownData.length = 0
      Project.get { id: $scope.studentProjectId }, (project) ->
        # $scope.burndownData.push(project.burndown_chart_data...)
        $scope.burndownData = project.burndown_chart_data

    #
    # Finds max end range for chart defined as 2 weeks (12096e5 ms) after unit's end date
    #
    $scope.lateEndDate = () ->
      return new Date(+new Date($scope.unit.end_date) + 12096e5).getTime() / 1000

    $scope.taskCount = () ->
      $scope.unit.task_definitions.length
)
.directive('taskList', ->
  restrict: 'E'
  templateUrl: 'projects/partials/templates/task-list.tpl.html'
  controller: ($scope, $modal, User, Unit) ->
    # TODO
)
.directive('labList', ->
  restrict: 'E'
  templateUrl: 'projects/partials/templates/lab-list.tpl.html'
  controller: ($scope, $modal, User, Project, alertService) ->
    # Todo, write...
    $scope.sortOrder = 'abbreviation'
    $scope.setTutorial = (id) ->
      Project.update(
        { id: $scope.project.project_id, tutorial_id: id }
        (project) -> $scope.project.tute = project.tute
        (response) -> alertService.add("danger", response.data.error, 6000)
      )
)
.directive('taskFeedback', ->
  restrict: 'E'
  templateUrl: 'projects/partials/templates/task-feedback.tpl.html'
  scope:
    unit: '='
    project: '='
    activeTask: '='
    submittedTasks: '='
    assessingUnitRole: '='
  controller: ($scope, $modal, $state, $stateParams, TaskFeedback, TaskComment, Task, Project, taskService, groupService, alertService, projectService) ->

    #
    # Comment code
    #
    $scope.comment = { text: "" }
    $scope.currentPage = 1
    $scope.pageSize = 3
    $scope.maxSize = 5

    #
    # Active task tab group
    #
    $scope.tabsData =
      taskSheet:
        title: "View Task Sheet"
        subtitle: "The task sheet contains the requirements of this task"
        icon: "fa-info"
        seq: 0
      fileUpload:
        title: "Upload Submission"
        subtitle: "Upload your submission so it is ready for your tutor to mark"
        icon: "fa-upload"
        seq: 1
      viewSubmission:
        title: "View Submission"
        subtitle: "View the latest submission you have uploaded"
        icon: "fa-file-o"
        seq: 2
      viewComments:
        title: "View Comments"
        subtitle: "Write and read comments between you and your tutor"
        icon: "fa-comments-o"
        seq: 3
      plagiarismReport:
        title: "View Similarities Detected"
        subtitle: "See the other submissions and how closely they relate to your submission"
        icon: "fa-eye"
        seq: 4

    #
    # Sets the active tab
    #
    $scope.setActiveTab = (tab) ->
      # Do nothing if we're switching to the same tab
      return if tab is $scope.activeTab
      $scope.activeTab = tab

    #
    # Checks if tab is the active tab
    #
    $scope.isActiveTab = (tab) ->
      tab is $scope.activeTab

    #
    # Loading the active task
    #
    $scope.setActiveTask = (task) ->
      return if task == $scope.activeTask
      $scope.activeTask = task
      fetchTaskComments(task)

    # Ensure there is an active task!
    $scope.setActiveTask($scope.activeTask)

    if $stateParams.viewing == 'feedback' || ($scope.activeTask && $scope.activeTask.has_pdf)
      $scope.setActiveTab($scope.tabsData['viewSubmission'])
    else if $stateParams.viewing == 'submit'
      $scope.setActiveTab($scope.tabsData['fileUpload'])
    else
      $scope.setActiveTab($scope.tabsData['taskSheet'])

    #
    # Comment text area enter to submit comment
    #
    fetchTaskComments = (task) ->
      TaskComment.query {task_id: task.id},
        (response) ->
          task.comments = response

    #
    # Functions from taskService to get data
    #
    $scope.statusData  = taskService.statusData
    $scope.statusClass = taskService.statusClass
    $scope.daysOverdue = taskService.daysOverdue

    $scope.activeStatusData = ->
      $scope.statusData($scope.activeTask)

    $scope.groupSetName = (id) ->
      groupService.groupSetName(id, $scope.unit)

    $scope.hideGroupSetName = ->
      gsNames = _.pluck $scope.unit.group_sets.id
      gsNames.length is 1 and gsNames[0] is null

    $scope.recreatePDF = ->
      taskService.recreatePDF($scope.activeTask, null)

    #
    # Statuses tutors/students may change task to
    #
    $scope.studentStatuses  = taskService.switchableStates.student
    $scope.tutorStatuses    = taskService.switchableStates.tutor
    $scope.taskEngagementConfig = {
      studentTriggers: $scope.studentStatuses.map (status) ->
        { status: status, label: taskService.statusLabels[status], iconClass: taskService.statusIcons[status], taskClass: _.trim(_.dasherize(status), '-'), helpText: taskService.helpText(status) }
      tutorTriggers: $scope.tutorStatuses.map (status) ->
        { status: status, label: taskService.statusLabels[status], iconClass: taskService.statusIcons[status], taskClass: _.trim(_.dasherize(status), '-'), helpText: taskService.helpText(status) }
      }

    $scope.activeClass = (status) ->
      if status == $scope.activeTask.status
        "active"
      else
        ""

    $scope.triggerTransition = (status) ->
      oldStatus = $scope.activeTask.status

      if (status == 'ready_to_mark' || status == 'need_help') and $scope.activeTask.upload_requirements.length > 0
        $scope.setActiveTab($scope.tabsData['fileUpload'])
        return # handle with the uploader...
      else
        Task.update(
          { id: $scope.activeTask.id, trigger: status }
          # Success
          (value) ->
            $scope.activeTask.status = value.status
            projectService.updateTaskStats($scope.project, value.new_stats)

            if value.status == status
              alertService.add("success", "Status saved.", 2000)
            else
              alertService.add("info", "Status change was not changed.", 4000)
          # Fail
          (value) ->
            $scope.activeTask.status = oldStatus
            alertService.add("danger", value.data.error, 6000)
        )
)
.directive('viewComments', ->
  restrict: 'E'
  templateUrl: 'projects/partials/templates/view-comments.tpl.html'
  controller: ($scope, $modal, $state, TaskFeedback, TaskComment, Task, Project, taskService, alertService, projectService) ->

    $scope.checkCommentTextareaEnter = (e) ->
      e = e || window.event
      # Hit return and not shift key
      if e.keyCode is 13 and not e.shiftKey
        $scope.addComment()
        return false
      return true

    $scope.addComment = () ->
      TaskComment.create { task_id: $scope.activeTask.id, comment: $scope.comment.text },
        (response) ->
          if ! $scope.activeTask.comments
            $scope.activeTask.comments = []
          $scope.activeTask.comments.unshift response
          $scope.comment.text = ""
        (error) ->
          alertService.add("danger", "Request failed, cannot add a comment at this time.", 2000)

    $scope.deleteComment = (id) ->
      TaskComment.delete { task_id: $scope.activeTask.id, id: id },
        (response) ->
          #$scope.activeTask.comments.splice response
          $scope.activeTask.comments = $scope.activeTask.comments.filter (e) -> e.id != id
        (error) ->
          alertService.add("danger", "Request failed, you cannot delete this comment.", 2000)
)
.directive('viewSubmission', ->
  restrict: 'E'
  templateUrl: 'projects/partials/templates/view-submission.tpl.html'
  controller: ($scope, TaskFeedback) ->
    $scope.taskUrl = ->
      TaskFeedback.getTaskUrl($scope.activeTask)

    #
    # Exceptional scenarios
    #
    $scope.taskStillProcessing = () ->
      $scope.activeTask.processing_pdf
    $scope.notSubmitted = () ->
      not $scope.activeTask.has_pdf and (not $scope.taskStillProcessing())
)