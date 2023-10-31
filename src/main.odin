package cass

import "core:c/libc"
import "core:crypto/md5"
import "core:fmt"
import "core:intrinsics"
import "core:time"
import "core:strings"
import "core:mem"
import "core:os"
import "core:sync"
import "core:sys/unix"
import "core:thread"

import "vendor:sdl2"
import stbtt "vendor:stb/truetype"

import vi "violin:vsr"
import vig "violin:gui"

CassAppError :: enum {
  Success,
  NotYetDetailed = auto_cast vi.Error.MAX_EXTENT_VALUE,
  NetworkError,
  AllocationFailed,
  FailedToOpenCurrentDirectory,
  FailedToReadCurrentDirectory,
  FailedToReadDirectoryFile,
}

CassState :: enum {
  Initializing,
  ConnectingToServer,
  RetrievingServiceInfo,
  ClientVerified,
  FatalError,
}

AlternateThreadState :: enum {
  Uninitiated,
  Running,
  Stopped,
}

CassAppData :: struct {
  // settings: ClientSettings,
  alt_thread: ^thread.Thread,
  alt_err: CassAppError,
  alt_state: AlternateThreadState,
  alt_sync: sync.Mutex,

  vctx: ^vi.Context,
  gui: ^vig.GUIRoot,

  strbld: strings.Builder,

  loop_start: time.Time,
  frame_elapsed, total_elapsed: f32,
  min_fps, max_fps: int,
  historical_frame_count: int,

  state: CassState,
  state_sync: sync.Mutex,
  state_transition_time: time.Time,
  state_retry_count: int,
}

main :: proc() {
  lerr := _begin_game_loop()
  if lerr != .Success {
    if lerr < auto_cast vi.Error.MAX_EXTENT_VALUE {
      fmt.println("Cass App Error:", cast(vi.Error) lerr)
    } else {
      fmt.println("Cass App Error:", lerr)
    }
    os.exit(auto_cast lerr)
  }
  fmt.println("Launching Cass Application...")
  return
}

_destroy_app_data :: proc(cad: ^CassAppData) {
  vi.quit(cad.vctx)
  free(cad)
}

_initialize_app_data :: proc() -> (cad: ^CassAppData, err: CassAppError) {
  cad = new(CassAppData)
  cad.strbld = strings.builder_make_len_cap(0, 1024)

  // Initialize Renderer
  verr: vi.Error
  cad.vctx, verr = vi.init(1700, 740) // TODO -- find a more elegant way to package and make available violins resources(shaders)
  if verr != .Success {
    fmt.println("init problem:", verr)
    err = auto_cast verr
    return
  }
  sdl2.SetWindowBordered(cad.vctx.window, false)

  return
}

_begin_game_loop :: proc() -> CassAppError {
  rctx: ^vi.RenderContext
  verr: vi.Error

  // Application Data
  fmt.println("Initializing Application Data...")
  cad: ^CassAppData = _initialize_app_data() or_return
  defer _destroy_app_data(cad)

  // Temp Load Resources
  // // RenderPasses
  // rpass2d: vi.RenderPassResourceHandle
  // // rpass2d, err = vi.create_render_pass(cad.vctx, { })
  // // if err != .Success {
  // //   fmt.println("create_render_pass 2 error")
  // //   return .NotYetDetailed
  // // }
  // // defer vi.destroy_resource(cad.vctx, rpass2d)
  
  // // Resources
  stamp_shaders: ^vi.StampShaders
  stamp_shaders, verr = vi.load_stamp_shaders("../dep/violin/spirv")
  if verr != .Success do return auto_cast verr
  defer vi.destroy_stamp_shaders(&stamp_shaders)

  stamprr: vi.StampRenderResourceHandle
  stamprr, verr = vi.init_stamp_batch_renderer(cad.vctx, stamp_shaders, { .IsPresent }) // .HasPreviousColorPass,
  if verr != .Success do return auto_cast verr
  defer vi.destroy_resource(cad.vctx, stamprr)

  // // parth: vi.TextureResourceHandle
  // // parth, verr = vi.load_texture_from_file(cad.vctx, "data/textures/parthenon.jpg")
  // // if verr != .Success do return auto_cast verr
  // // defer vi.destroy_resource(cad.vctx, parth)

  // // font: vi.FontResourceHandle
  // // font, verr = vi.load_font(cad.vctx, "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf", 25)
  // // if verr != .Success do return auto_cast verr
  // // defer vi.destroy_resource(cad.vctx, font)

  // Create Graphical User Interface
  _initialize_app_data_gui(cad) or_return
  defer vig.destroy_gui(cad.vctx, &cad.gui)
  
  // // rd2: vi.RenderData
  // // rp2: vi.RenderProgram
  // // rd2, rp2, err = load_textured_rect(cad.vctx, rpass2d)
  // // defer vi.destroy_render_program(cad.vctx, &rp2)
  // // defer vi.destroy_render_data(cad.vctx, &rd2)
  // // if err != .Success {
  // //   fmt.println("load_textured_rect error")
  // //   return .NotYetDetailed
  // // }

  // Variables
  ft: vi.FrameTime
  vi.init_frame_time(&ft)
  FPS_PRINT_PERIOD :: 7500
  @(static) fps_print_time: time.Time
  fps_print_time = time.time_add(time.now(), -time.Millisecond * (FPS_PRINT_PERIOD - 2000))
  do_break_loop: bool

  // Loop
  fmt.println("Init Success. Entering Game Loop...")
  loop : for {
    // FPS
    vi.frame_time_update(&ft)

    // --- ###  Update  ### ---
    // Update
    do_break_loop = update(cad) or_return
    if do_break_loop do break loop

    // --- ### Draw the Frame ### ---
    // fmt.println("hereA")
    if rctx, verr = vi.begin_present(cad.vctx); verr != .Success do return .NotYetDetailed

    // // 2D
    // if vi.begin_render_pass(rctx, rpass2d) != .Success do break loop    

    // if vi.draw_indexed(rctx, &rp2, &rd2) != .Success do break loop

    if vi.stamp_begin(rctx, stamprr) != .Success do return .NotYetDetailed

    sq := vi.Rectf{100, 100, 300, 200}
    co := vi.COLOR_Blue
    if vi.stamp_colored_rect(rctx, stamprr, &sq, &co) != .Success do return .NotYetDetailed
    sq = vi.Rectf{200, 200, 100, 300}
    co = vi.COLOR_Chocolate
    if vi.stamp_colored_rect(rctx, stamprr, &sq, &co) != .Success do return .NotYetDetailed
    // sq = vi.Rectf{280, 60, 420, 210}
    // co = vi.Color { 1.0, 0.0, 0.0, 0.7 }
    // if vi.stamp_textured_rect(rctx, stamprr, parth, &sq, &co) != .Success do return .NotYetDetailed

    // sq = vi.Rectf{40, 272, 256, 256}
    // co = vi.COLOR_Mint
    // fontr: rawptr
    // fontr, verr = vi.load_font(ctx)
    // if verr != .Success do return auto_cast verr
    // if vi.stamp_textured_rect(rctx, stamprr, (cast(^vi.Font)fontr).texture, &sq, &co) != .Success do return .NotYetDetailed
    // vi.stamp_text(rctx, stamprr, font, "Hello World", 300, 400, auto_cast &co)

    if vig.render_gui(rctx, stamprr, cad.gui) != .Success do return .NotYetDetailed

    if vi.end_present(rctx) != .Success {
      fmt.println("end_present error")
      return .NotYetDetailed
    }

    // Auto-Leave
    // -- Space per frame
    // for  {
    //   event: sdl2.Event
    //   sdl2.PollEvent(&event);
    //   if event.type == .KEYDOWN {
    //     if event.key.keysym.sym == .ESCAPE || event.key.keysym.sym == .F4 {
    //       break loop
    //     }
    //     if event.key.keysym.sym == .SPACE {
    //       break
    //     }
    //   }
    // }
    // -- Fixed Frame Count
    // if recent_frame_count > 0 do break
    // break

    if time.diff(fps_print_time, time.now()) > time.Millisecond * FPS_PRINT_PERIOD {
      fps_print_time = time.now()
      fmt.println("fps:", cast(int) (1.0 / ft.running_avg), "99%:", cast(int) (1.0 / ft.ninety_ninth))
    }
  }

  fmt.println("FrameCount:", ft.historical_frame_count, " ( max:", cast(f32) 1.0 / ft.max_frame, "  min:",
    cast(f32) 1.0 / ft.min_frame, " 99%:", ft.ninety_ninth, " avg:",
    cast(f32) ft.historical_frame_count / cast(f32) time.diff(ft.init_time, time.now()) /
    cast(f32) time.Second, ")")

  // if mod += 1; mod % 10 == 3 {
  //   fmt.println("fps:", _recent_frame_count)
  //   // break loop
  // }
  
  // avg_fps := cast(int) (cast(f64)(ft.historical_frame_count + ft.recent_frame_count) / time.duration_seconds(
  //   time.diff(ft.init_time, ft.now)))
  // fmt.println("FrameCount:", ft.historical_frame_count + ft.recent_frame_count, " ( max:", ft.max_fps, "  min:",
  //   ft.min_fps, " avg:", avg_fps, ")")

  return .Success
}

_initialize_app_data_gui :: proc(using cad: ^CassAppData) -> (err: CassAppError) {
  // Create the gui
  verr: vi.Error
  cad.gui, verr = vig.create_gui_root(cad.vctx, "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf", 25)
  if verr != .Success do return auto_cast verr // cad.vctx, stamprr, font

  // Label
  label: ^vig.Label
  if label, verr = vig.create_label(auto_cast cad.gui); verr != .Success do return auto_cast verr
  
  label.background_color = vi.COLOR_DarkGray
  label.text = "Hello World"

  // Create a panel
  panel: ^vig.StackContainer
  if panel, verr = vig.create_stack_container(auto_cast cad.gui); verr != .Success do return auto_cast verr

  panel.background_color = vi.COLOR_DarkSlateGray
  panel.margin = {200, 80, 16, 40}

  // button: ^vig.Button
  // button, err= vig.create_button(auto_cast gui)

  return
}

update :: proc(using cad: ^CassAppData) -> (do_end_loop: bool, err: CassAppError) {
  verr: vi.Error

  do_end_loop = _update_launcher(cad) or_return
  if do_end_loop do return

  do_end_loop = _update_input(cad) or_return
  if do_end_loop do return

  // Update GUI
  verr = vig.update_gui(cad.gui)
  if verr != .Success {
    err = auto_cast verr
    return
  }

  return
}

_update_launcher :: proc(cad: ^CassAppData) -> (do_end_loop: bool, err: CassAppError) {
  sync.mutex_lock(&cad.state_sync)
  defer sync.mutex_unlock(&cad.state_sync)

  // Update App
  // switch cad.state {
  //   case .Initializing:
  //     return _update_app_initializing(cad)
  //   case .FatalError:
  //     do_end_loop = true
  //   case:
  //     fmt.println("TODO unhandled state:", cad.state)
  // }
  
  return
}

// _update_launcher_initializing :: proc(cad: ^CassAppData) -> (do_end_loop: bool, err: CassAppError) {
//   // Begin Concurrent initialization
//   cad.alt_thread = thread.create_and_start_with_data(auto_cast cad, _concurrent_initialize)

//   cad.state = .Initializing
//   cad.state_transition_time = time.now()

//   return
// }

// _concurrent_initialize :: proc(state: rawptr) {
//   cad: ^CassAppData = auto_cast state

//   sync.mutex_lock(&cad.alt_sync)
//   cad.alt_state = .Running
//   sync.mutex_unlock(&cad.alt_sync)
//   defer {
//     sync.mutex_lock(&cad.alt_sync)
//     cad.alt_state = .Stopped
//     // fmt.println("Concurrent thread stopped:", cast(^ExistingFileSearch)&cad.alt_data)
//     sync.mutex_unlock(&cad.alt_sync)
//     // fmt.println("Concurrent thread ended")
//   }

//   // Initialize Here
// }

_update_input :: proc(using cad: ^CassAppData) -> (do_end_loop: bool, err: CassAppError) {
  // Handle SDL Events (incl. Input)
	event: sdl2.Event
  for sdl2.PollEvent(&event) {
		#partial switch event.type {
      case .QUIT:
        do_end_loop = true
        return
      case .KEYDOWN, .KEYUP:
        #partial switch event.key.keysym.sym {
          case .ESCAPE, .F4:
            do_end_loop = true
            return
          case:
        }
        fallthrough
      case .KEYMAPCHANGED, .TEXTINPUT:
        fallthrough
      case .MOUSEMOTION, .MOUSEWHEEL, .MOUSEBUTTONDOWN, .MOUSEBUTTONUP:
        handled, verr := vig.handle_gui_event(cad.gui, &event)
        if !handled {
          // Send the event to the world
          // input_event_world(cad, event) or_return
        }
        // fmt.println(".TEXTINPUT:", event.text.text)
      case .TEXTEDITING:
        // Do not know what to do with this
        // if cad.historical_frame_count > 1000 {
        //   fmt.println("Unhandled GUI Event .TEXTEDITING:", event.edit.text)
        // }
      case:
        fmt.println("Unknown event:", event.type)
      case .WINDOWEVENT:
        // fmt.println("Window event:", event.window.event)
        #partial switch event.window.event {
          case .RESIZED, .RESTORED, .SIZE_CHANGED:
            // fmt.println("Window resized:", event.window.data1, event.window.data2)
            // vi.handle_resized_presentation(ctx)
            vctx.framebuffer_resized = true
            // TODO -- resize GUI
          case .CLOSE:
            do_end_loop = true
            return
        }
    }
  }

  return
}