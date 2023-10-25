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
    "procedures": [
        {
            "name": "create_2D_game",
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
      "content": "You are manager of the team that is responsible for handling of feature requests involving player input in the game. You are responsible for delegating the work required to correctly implement the feature to the rest of the team through its various stages of completion. The Input Specialist should be consulted first for directions and information on how to implement the feature. The Coder should be consulted next to create code that will implement the feature. The Bug Reviewer and Input Specialist should then be consulted to ensure the code will procedure and not introduce errors. The Technical Writer should lastly be consulted for documentation of the code. When complete you will declare the Implementation Complete."
    },
    {
      "role": "user",
      "content": "[FeatureRequest] When I hold down right click, I want the character to rotate according to the horizontal mouse movement. The camera alone should also respond to the vertical mouse movement."
    }
  ]
}'
#############################################################
#############################################################
#############################################################
curl https://api.openai.com/v1/chat/completions -H "Content-Type: application/json" -H "Authorization: Bearer $(cat OpenAI_API_Key.txt)"   -d '{
  "model": "gpt-3.5-turbo",
  "messages": [
    {
      "role": "system",
      "content": "You are the player input specialist developer for a game project. Your task is to create a bullet pointed list (step-by-step process) of implementable actions that your software programmer can take to address a feature request from a user. The game is a 3D MMORPG written using the ODIN programming language and uses SDL2 for mouse/keyboard input. The usage pattern is to set SDL2 events to the PlayerInput data structure, and then to process the events in the game loop.\nClientSettings :: struct {\nmouse_x_sensitivity, mouse_y_sensitivity: f32,\nkey_map: map[sdl2.Keycode]PlayerInputActionFlags,\nmouse_map: map[u8]PlayerInputActionFlags,\n}\nPlayerInput :: struct {\ninput_action: PlayerInputActionFlags,\nmouse_pos: vec2i,\n// Holds the x and y mouse movement for each frame\nmouse_delta: vec2i,\nmouse_wheel_delta: f32,\nmouse_locked: bool,\n// TODO: Setting the mouse position triggers an event to describe it, it cannot be suppressed/bypassed, so this is done here.\n// Not Ideal, chance to skip other mouse events during the succeeding frame\nskip_mouse_events: bool,\n}\n\nPlayerInputActionFlags :: distinct bit_set[PlayerInputActionFlag; u32]\nPlayerInputActionFlag :: enum(u32) {\n// Continuous Actions -- These are not reset unless the button for these is released\nForward = 0,\nBackward,\nStrafeLeft,\nStrafeRight,\n// Crouch,\n// Toggled Actions -- TODO\n// Something Else -- TODO\nEngageWorld,\n// Discrete Actions -- These are reset after the first frame they are pressed\nJump,\nSprint,\nFire,\nMAX_EXTENT_VALUE,\n}\n\nPlayer :: struct {\npos: vec3,\nrot: f32,\ncam_pitch: f32,\nspeed: f32,\nmodel: ^GLTFAsset,\n}\n\nCurrent key and mouse Mappings are as follows:  client.settings.key_map[.W] = {.Forward}\nclient.settings.key_map[.S] = {.Backward}\nclient.settings.key_map[.A] = {.StrafeLeft}\nclient.settings.key_map[.D] = {.StrafeRight}\nclient.settings.key_map[.SPACE] = {.Jump}\nclient.settings.key_map[.LSHIFT] = {.Sprint}\nclient.settings.mouse_map[sdl2.BUTTON_LEFT] = {.Fire}\nclient.settings.mouse_map[sdl2.BUTTON_RIGHT] = {.EngageWorld}\n\nInput Flow Patterns:\n- All Mouse and Keyboard input is already handled by updating the mouse_pos, mouse_delta, mouse_wheel_delta fields of the PlayerInput data structure in the procedure input_event_world(event: sdl2.Event). All mouse and keyboard button inputs are mapped through client.settings maps to a PlayerInputActionFlag and stored in the input_action field as set or unset. Player Movement and Camera View Project is updated in the update_player_movement procedure."
    },
    {
      "role": "user",
      "content": "[FeatureRequest] When I hold down right click, I want the character to rotate according to the horizontal mouse movement. The camera alone should also respond to the vertical mouse movement."
    }
  ]
}'
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
{
  "id": "chatcmpl-8DLMqdSeRYm8VVL9ecPD30qF3BDoB",
  "object": "chat.completion",
  "created": 1698191092,
  "model": "gpt-3.5-turbo-0613",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "To address this feature request, the software programmer can take the following steps:
        
        1. Modify the PlayerInput struct to include a new flag for the right mouse button action:
          - Add \"RotateYaw\" to the PlayerInputActionFlag enum.
          - Add \"RotateYaw\" flag to the PlayerInputActionFlags bit set in the PlayerInput struct.
          - Update the client.settings.mouse_map to map the right mouse button to the RotateYaw action.
              
        2. Modify the input_event_world procedure to handle the new RotateYaw action when the right mouse button is pressed:
          - Check if the event is an SDL_MOUSEBUTTONDOWN event and if the button is the right mouse button.
          - Set the RotateYaw flag in the input_action field of PlayerInput based on the event type.
        3. Modify the input_event_world procedure to handle the new RotateYaw action when the right mouse button is released:
          - Check if the event is an SDL_MOUSEBUTTONUP event and if the button is the right mouse button.
          - Clear the RotateYaw flag in the input_action field of PlayerInput based on the event type.
        4. Update the update_player_movement procedure to use the RotateYaw flag to rotate the character and camera:
          - Check if the RotateYaw flag is set in the input_action field of PlayerInput.
          - If the flag is set, update the character's rotation (rot) based on the horizontal mouse movement (mouse_delta.x).
          - Update the camera's pitch (cam_pitch) based on the vertical mouse movement (mouse_delta.y).
        5. Test the implemented feature to ensure that the character rotates according to the horizontal mouse movement when the right mouse button is held down and that the camera responds to the vertical mouse movement.\n\n6. Optimize and refine the implementation as needed based on user feedback and performance considerations.\n\n7. Document the changes made and update any relevant documentation or user guides to reflect the new feature.\n\n8. Communicate the implementation of the feature to the user and gather feedback for further improvements."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 646,
    "completion_tokens": 407,
    "total_tokens": 1053
  }
}
#############################################################
#############################################################
#############################################################


