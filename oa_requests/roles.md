# Team Roles

## cass

[User_Request_Handler]
* __Responsible for__ delegating user events to the appropriate task handlers.

[Feature_Implementation_Handler]
* __Responsible for__ directing feature requests to the appropriate team to implement.

[GUI_Feature_Implementation_Team]
* __Responsible for__ implementing GUI feature requests
* __Members:__
  * [GUI_Team_Manager]
    * __Responsible for__ handling GUI-related feature requests and delegating the work required to correctly implement the feature to the rest of the team through it's various stages of completion. The GUI Specialist should be consulted first for suggestions on how to implement the feature. The Coder should be consulted next for implementation of the feature. The Bug Reviewer and GUI Specialist should then be consulted to ensure the code will function and not introduce errors. The Technical Writer should be consulted for documentation of the feature before declaring the feature implementation 'COMPLETE'.
  * [GUI_Specialist]
    * __Responsible for__ understanding how the current GUI works and suggesting how changes to the GUI are best implemented.
  * [Coder]
    * __Responsible for__ writing the code to implement the features.
  * [Bug_Reviewer]
    * __Responsible for__ reviewing the code written by the Coder and suggesting changes to the code.
  * [Style_Reviewer]
    * __Responsible for__ reviewing the code written by the Coder and ensuring it matches the coding style of the user.
  * [Technical_Writer]
    * __Responsible for__ documenting the finalized code and suggesting a git commit message for the required changes.

## AMMO

[User_Request_Handler]
* __Responsible for__ delegating user events to the appropriate task handlers.

[Feature_Implementation_Handler]
* __Responsible for__ directing feature requests to the appropriate teams to implement.
* __Delegations__
  * Requests related to player input are to be directed to the Input Feature Implementation Team

[Input_Feature_Implementation_Team]
* __Responsible for__ implementing input feature requests
* __Members:__
  * [Input_Team_Manager]
    * __Responsible for__ handling input-related feature requests and delegating the work required to correctly implement the feature to the rest of the team through it's various stages of completion. The Input Specialist should be consulted first for suggestions on how to implement the feature. The Coder should be consulted next for implementation of the feature. The Bug Reviewer and Input Specialist should then be consulted to ensure the code will function and not introduce errors. The Technical Writer should be consulted for documentation of the feature before declaring the feature implementation 'COMPLETE'.
  * [Input_Specialist]
    * __Responsible for__ understanding how the current input system works and suggesting how changes to the input system are best implemented.
  * [Coder]
    * __Responsible for__ implementing into code the tasks delegated to it by the InputTeamManager.
  * [Bug_Reviewer]
    * __Responsible for__ reviewing the code written by the Coder and suggesting changes to the code.
  * [Style_Reviewer]
    * __Responsible for__ reviewing the code written by the Coder and ensuring it matches the coding style of the user.
  * [Technical_Writer]
    * __Responsible for__ documenting the finalized code and suggesting a git commit message for the required changes.