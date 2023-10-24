curl https://api.openai.com/v1/chat/completions   -H "Content-Type: application/json"   -H "Authorization: Bearer $OPENAI_API_KEY"   -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {
        "role": "system",
        "content": "You are a helpful software creation assistant."
      },
      {
        "role": "assistant",
        "content": "Hello, I am the helpful assistant."
      },
      {
        "role": "user",
        "content": "List the steps I need to take to create a new blank SDL2 Game with Odin."
      }
    ]
    "functions": [
        {
            "name": "create_2D_game",
        }
    ]
  }'
#############################################################
curl https://api.openai.com/v1/chat/completions -H "Content-Type: application/json" -H "Authorization: Bearer $(cat OpenAI_API_Key.txt)"   -d '{
  "model": "gpt-3.5-turbo",
  "messages": [
    {
      "role": "system",
      "content": "You are the player input specialist developer for a game project. Your task is to create a bullet pointed list (step-by-step process) of implementable actions that your software programmer can take to address a feature request from a user. The game is a 3D MMORPG written using the ODIN programming language and uses SDL2 for mouse/keyboard input. The usage pattern is to set SDL2 events to the PlayerInput data structure, and then to process the events in the game loop.\nPlayerInput :: struct {\ninput_action: PlayerInputActionFlags,\nmouse_pos: vec2i,\nmouse_delta: vec2i,\nmouse_wheel_delta: f32,\nmouse_locked: bool,\n// TODO: Setting the mouse position triggers an event to describe it, it cannot be suppressed/bypassed, so this is done here.\n// Not Ideal, chance to skip other mouse events during the succeeding frame\nskip_mouse_events: bool,\n}\n\nPlayerInputActionFlags :: distinct bit_set[PlayerInputActionFlag; u32]\nPlayerInputActionFlag :: enum(u32) {\n// Continuous Actions -- These are not reset unless the button for these is released\nForward = 0,\nBackward,\nStrafeLeft,\nStrafeRight,\n// Crouch,\n// Toggled Actions -- TODO\n// Something Else -- TODO\nEngageWorld,\n// Discrete Actions -- These are reset after the first frame they are pressed\nJump,\nSprint,\nFire,\nMAX_EXTENT_VALUE,\n}\n\nPlayer :: struct {\npos: vec3,\nrot: f32,\ncam_pitch: f32,\nspeed: f32,\nmodel: ^GLTFAsset,\n}"
    },
    {
      "role": "user",
      "content": "[FeatureRequest] When I hold down right click, I want the character to rotate according to the horizontal mouse movement. The camera alone should also respond to the vertical mouse movement."
    }
  ]
}'
#############################################################
#############################################################
curl https://api.openai.com/v1/chat/completions -H "Content-Type: application/json" -H "Authorization: Bearer $(cat OpenAI_API_Key.txt)"   -d '{
  "model": "gpt-3.5-turbo",
  "messages": [
    {
      "role": "system",
      "content": "You are manager of the team that is responsible for handling of feature requests involving player input in the game. You are responsible for delegating the work required to correctly implement the feature to the rest of the team through its various stages of completion. The Input Specialist should be consulted first for directions and information on how to implement the feature. The Coder should be consulted next to create code that will implement the feature. The Bug Reviewer and Input Specialist should then be consulted to ensure the code will function and not introduce errors. The Technical Writer should lastly be consulted for documentation of the code. When complete you will declare the Implementation Complete."
    },
    {
      "role": "user",
      "content": "[FeatureRequest] When I hold down right click, I want the character to rotate according to the horizontal mouse movement. The camera alone should also respond to the vertical mouse movement."
    }
  ]
}'
#############################################################


