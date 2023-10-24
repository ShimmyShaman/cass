# Examples

## Interaction

* [Command]When I hold down right click, I want the character to rotate according to the horizontal mouse movement. The camera alone should also respond to the vertical mouse movement.
  * [Answer]
    * Make the following changes to the update_player_movement() function in the world.odin file:
      ```odin
      // Player View/Rotation
      if input.mouse_locked != .EngageWorld in input.input_action {
        if .EngageWorld in input.input_action {
          // Engage the world -- Lock the mouse to the screen and hide the cursor
          // TODO ? -- Check Return Value for functions that can fail
          sdl2.CaptureMouse(true)
          // sdl2.SetRelativeMouseMode(true)
          sdl2.SetWindowGrab(vctx.window, true)
          input.mouse_locked = true
        } else {
          // Disengage the world -- Unlock the mouse from the screen and show the cursor
          sdl2.CaptureMouse(false)
          // sdl2.SetRelativeMouseMode(false)
          sdl2.SetWindowGrab(vctx.window, false)
          input.mouse_locked = false
        }
      }
      if input.mouse_locked {
      // Player Orientation
        player.rot += mx.wrap(cast(f32) input.mouse_delta.x * settings.mouse_x_sensitivity, mx.PI * 2)
        player.cam_pitch = clamp(player.cam_pitch + cast(f32) input.mouse_delta.y * settings.mouse_y_sensitivity,
                            -mx.PI * 15 / 16, mx.PI * 15 / 16)

        sdl2.WarpMouseInWindow(vctx.window, input.mouse_pos.x, input.mouse_pos.y)
        // fmt.println("Warping mouse to", input.mouse_pos.x, input.mouse_pos.y)
        input.skip_mouse_events = true
      }
      ```
  * _Relevant Context_:
    * PlayerInput is handled through updating the PlayerInput data structure in an input_event-like function then updating in a seperate update_movement-like function. The EngageWorld flag is set/cleared to the input_action field of the PlayerInput data structure upon press/release of the right mouse button.
    * the update_player_movement() function in the world.odin file is the most appropriate place to handle this.