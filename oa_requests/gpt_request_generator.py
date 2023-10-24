

roles_dot_md = """[User Request Handler]
* __Responsible for__ delegating user events to the appropriate task handlers.

[Feature Implementation Handler]
* __Responsible for__ directing feature requests to the appropriate feature implementation team.

[Input Feature Implementation Team]
* __Responsible for__ implementing input feature requests
  * [InputTeamManager]
    * __Responsible for__ handling input-related feature requests and delegating the work required to correctly implement the feature to the rest of the team through it's various stages of completion. The Input Specialist should be consulted first for suggestions on how to implement the feature. The Coder should be consulted next for implementation of the feature. The Bug Reviewer and Input Specialist should then be consulted to ensure the code will function and not introduce errors. The Technical Writer should be consulted for documentation of the feature before declaring the feature implementation 'COMPLETE'.
  * [InputSpecialist]
    * __Responsible for__ understanding how the current input system works and suggesting how changes to the input system are best implemented.
  * [Coder]
    * __Responsible for__ implementing into code the tasks delegated to it by the InputTeamManager.
  * [BugReviewer]
    * __Responsible for__ reviewing the code written by the Coder and suggesting changes to the code.
  * [StyleReviewer]
    * __Responsible for__ reviewing the code written by the Coder and ensuring it matches the coding style of the user.
  * [TechnicalWriter]
    * __Responsible for__ documenting the finalized code and suggesting a git commit message for the required changes.
"""

# Class describing a role
class Role:
    def __init__(self, title, responsibility, is_team):
        self.title = title
        self.responsibility = responsibility
        self.is_team = is_team
        self.team_members = []

    def __str__(self):
        str = f"Role: {self.title}\n  Responsible for: {self.responsibility}\n"
        if self.is_team:
            str += f"  Is Team of {len(self.team_members)} members.\n"
        return str

# Function to parse the roles text
def parse_roles(roles: list, lines: list, line_index: int, indent: int = 0) -> int:
    i = line_index
    while i < len(lines):
        line = lines[i]
        is_role_title = False
        print(f"indent: {indent} line: '{line[indent * 2:]}'")
        if line.startswith("["):
            # Trim the line to remove the brackets and trailing spaces
            line = line[1:-1].strip()
            is_role_title = True
        elif indent > 0 and line[indent * 2:].startswith("* ["):
            for j < len(line):
            is_role_title = True

        if is_role_title == False:
            if len(line) == 0:
                i += 1
                continue
            else:
                print(f"Format Error: Expected Role Title!\n line_index: {line_index} line: '{line}'")
                return -1
        
        # Determine if the role is singular or a team
        team = line.endswith("Team")

        # Responsibility
        if i + 1 >= len(lines):
            print(f"Error: File End. Role {line} has no responsibility.")
            break
        next_line = lines[i+1].strip()
        if next_line.startswith("* __Responsible for__") != True:
            break
        
        responsibility = next_line[21:].strip()
        
        # Create a new role
        role = Role(line, responsibility, team)

        # Add the role to the list of roles
        roles.append(role)

        # If the role is a team, parse the team members
        if team == True:
            i = parse_roles(role.team_members, lines, i+2, indent+1)
            if i < 0:
                return False
        else:
            # Increment the line index
            i += 2

        print(role)

    return True


# Parse the roles text generating an array of roles
roles = []
lines = roles_dot_md.splitlines()
parse_roles(roles, lines, 0)





