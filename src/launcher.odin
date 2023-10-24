package launcher

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

import cn "common:net"
import cg "common:ag"
import cu "common:utility"

// TODO -- put this in a seperate 'config' file
GATEWAY_IP_ADDRESS :: "127.0.0.1"
GATEWAY_PORT :: 1434

import rf "core:reflect"

main :: proc() {

  // TODO -- debug convenience delay
  // time.sleep(time.Second * 1)

  // fmt.println("here...")

  lerr := _begin_game_loop()
  if lerr != .Success {
    if lerr == .DEBUG_SuppressLaunchClient {
      // fmt.println("DEBUG_SuppressLaunchClient", lerr)
      os.exit(1)
    }
    if lerr < auto_cast vi.Error.MAX_EXTENT_VALUE {
      fmt.println("Launcher Error:", cast(vi.Error) lerr)
    } else {
      fmt.println("Launcher Error:", lerr)
    }
    os.exit(auto_cast lerr)
  }
  fmt.println("Launching Game Client...")
  return
}

_initialize_launcher :: proc() -> (lnc: ^LauncherData, err: LauncherError) {
  lnc = new(LauncherData)
  lnc.strbld = strings.builder_make_len_cap(0, 1024)

  // Obtain the game version
  okay: bool
  lnc.current_version, okay = cg.get_game_client_version(cg.VERSION_INFO_FILENAME)
  // if !okay {
    
  // }
  // fmt.println("Current Game Version:", lnc.current_version)

  // Initialize Renderer
  verr: vi.Error
  lnc.vctx, verr = vi.init(960, 420) // TODO -- find a more elegant way to package and make available violins resources(shaders)
  if verr != .Success {
    fmt.println("init problem:", verr)
    err = auto_cast verr
    return
  }
  sdl2.SetWindowBordered(lnc.vctx.window, false)

  return
}

_destroy_launcher :: proc(lnc: ^LauncherData) {
  vi.quit(lnc.vctx)
  cn.end_async_client(&lnc.net)
  free(lnc)
}

_begin_game_loop :: proc() -> LauncherError {
  rctx: ^vi.RenderContext
  verr: vi.Error

  // Application Data
  lnc: ^LauncherData = _initialize_launcher() or_return
  defer _destroy_launcher(lnc)

  // Temp Load Resources
  // // RenderPasses
  // rpass3d, rpass2d: vi.RenderPassResourceHandle
  // rpass3d, verr = vi.create_render_pass(lnc.vctx, { .HasDepthBuffer })
  // if verr != .Success do return auto_cast verr
  // defer vi.destroy_resource(lnc.vctx, rpass3d)

  // // rpass2d, err = vi.create_render_pass(lnc.vctx, { })
  // // if err != .Success {
  // //   fmt.println("create_render_pass 2 error")
  // //   return .NotYetDetailed
  // // }
  // // defer vi.destroy_resource(lnc.vctx, rpass2d)
  
  // // Resources
  stamp_shaders: ^vi.StampShaders
  stamp_shaders, verr = vi.load_stamp_shaders("../violin/spirv")
  if verr != .Success do return auto_cast verr
  defer vi.destroy_stamp_shaders(&stamp_shaders)

  stamprr: vi.StampRenderResourceHandle
  stamprr, verr = vi.init_stamp_batch_renderer(lnc.vctx, stamp_shaders, { .IsPresent }) // .HasPreviousColorPass,
  if verr != .Success do return auto_cast verr
  defer vi.destroy_resource(lnc.vctx, stamprr)

  // // parth: vi.TextureResourceHandle
  // // parth, verr = vi.load_texture_from_file(lnc.vctx, "data/textures/parthenon.jpg")
  // // if verr != .Success do return auto_cast verr
  // // defer vi.destroy_resource(lnc.vctx, parth)

  // // font: vi.FontResourceHandle
  // // font, verr = vi.load_font(lnc.vctx, "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf", 25)
  // // if verr != .Success do return auto_cast verr
  // // defer vi.destroy_resource(lnc.vctx, font)

  // Create Graphical User Interface
  _initialize_launcher_gui(lnc) or_return
  defer vig.destroy_gui(lnc.vctx, &lnc.gui)
  
  // // rd2: vi.RenderData
  // // rp2: vi.RenderProgram
  // // rd2, rp2, err = load_textured_rect(lnc.vctx, rpass2d)
  // // defer vi.destroy_render_program(lnc.vctx, &rp2)
  // // defer vi.destroy_render_data(lnc.vctx, &rd2)
  // // if err != .Success {
  // //   fmt.println("load_textured_rect error")
  // //   return .NotYetDetailed
  // // }
  
  // // rd3: vi.RenderData
  // // rp3: vi.RenderProgram
  // // rd3, rp3, err = load_cube(lnc.vctx, rpass3d)
  // // defer vi.destroy_render_program(lnc.vctx, &rp3)
  // // defer vi.destroy_render_data(lnc.vctx, &rd3)
  // // if err != .Success {
  // //   fmt.println("load_cube error")
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
    do_break_loop = update(lnc) or_return
    if do_break_loop do break loop

    // --- ### Draw the Frame ### ---
    // fmt.println("hereA")
    if rctx, verr = vi.begin_present(lnc.vctx); verr != .Success do return .NotYetDetailed

    // 3D
    // if vi.begin_render_pass(rctx, rpass3d) != .Success do break loop

    // // Create ViewProj Matrix
    // eye := la.vec3{6.0 * sdl2.cosf(total_elapsed), 5 + sdl2.cosf(total_elapsed * 0.6) * 3.0, 6.0 * sdl2.sinf(total_elapsed)}
    // // sqd: f32 = 8.0 / la.length_vec2(la.vec2{eyevent.x, eyevent.z})
    // // eyevent.x *= sqd
    // // eyevent.z *= sqd
    // // eye := la.vec3{-3.0, 0, 0}
    // view := la.mat4LookAt(eye, la.vec3{0, 0, 0}, la.vec3{0, -1, 0})
    // proj := la.mat4Perspective(0.7, cast(f32)ctx.swap_chain.extent.width / cast(f32)ctx.swap_chain.extent.height, 0.1, 100)
    // vp := proj * view
    // // vp := view * proj
    // vi.write_to_buffer(ctx, pvp, &vp, size_of(la.mat4))

    // if vi.draw_indexed(rctx, &rp3, &rd3) != .Success do return

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

    if vig.render_gui(rctx, stamprr, lnc.gui) != .Success do return .NotYetDetailed

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

  if lnc.launch_client_on_exit {
    return .Success
  }

  return .DEBUG_SuppressLaunchClient
}

_initialize_launcher_gui :: proc(using lnc: ^LauncherData) -> (err: LauncherError) {
  // Create the gui
  verr: vi.Error
  lnc.gui, verr = vig.create_gui_root(lnc.vctx, "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf", 25)
  if verr != .Success do return auto_cast verr // lnc.vctx, stamprr, font

  // Label
  label: ^vig.Label
  if label, verr = vig.create_label(auto_cast lnc.gui); verr != .Success do return auto_cast verr
  
  label.background_color = vi.COLOR_DarkGray
  label.text = "Hello World"

  // Create a panel
  panel: ^vig.StackContainer
  if panel, verr = vig.create_stack_container(auto_cast lnc.gui); verr != .Success do return auto_cast verr

  panel.background_color = vi.COLOR_DarkSlateGray
  panel.margin = {200, 80, 16, 40}

  // button: ^vig.Button
  // button, err= vig.create_button(auto_cast gui)

  return
}

update :: proc(using lnc: ^LauncherData) -> (do_end_loop: bool, err: LauncherError) {
  verr: vi.Error

  do_end_loop = _update_launcher(lnc) or_return
  if do_end_loop do return

  do_end_loop = _update_input(lnc) or_return
  if do_end_loop do return

  // Update GUI
  verr = vig.update_gui(lnc.gui)
  if verr != .Success {
    err = auto_cast verr
    return
  }

  return
}

_update_launcher :: proc(lnc: ^LauncherData) -> (do_end_loop: bool, err: LauncherError) {
  sync.mutex_lock(&lnc.state_sync)
  defer sync.mutex_unlock(&lnc.state_sync)

  // Net Client Check
  if lnc.net != nil && (lnc.net.status == .Shutdown || lnc.net.status == .EndedDueToError) {
    fmt.println("Net Client Status:", lnc.net.status, "Ending Launcher.")
    do_end_loop = true
    return
  }

  // Update Launcher
  switch lnc.state {
    case .Initializing:
      return _update_launcher_initializing(lnc)
    case .ConnectingToServer:
      return _update_launcher_connecting_to_server(lnc)
    case .RetrievingServiceInfo:
      return _update_launcher_retrieving_service_info(lnc)
    case .ClientVerified:
      return _update_launcher_client_verified(lnc)
    case .FatalError:
      do_end_loop = true
    case:
      fmt.println("TODO unhandled state:", lnc.state)
  }
  
  return
}

_update_launcher_initializing :: proc(lnc: ^LauncherData) -> (do_end_loop: bool, err: LauncherError) {
  // Begin Concurrent initialization
  lnc.alt_thread = thread.create_and_start_with_data(auto_cast lnc, _concurrent_initialize)

  // Begin Network Connection
  nerr := cn.initialize_enet()
  if nerr != .Success {
    do_end_loop = true
    err = auto_cast nerr
    fmt.println("ERROR: Failed to initialize ENet")
    return
  }
  
  // Connect to the gateway server
  lnc.net, nerr = cn.begin_client_async(GATEWAY_IP_ADDRESS, GATEWAY_PORT,  cn.ClientCallbacks {
      callback_state = lnc,
      packet_received = _on_packet_received,
    })
  if nerr != .Success {
    do_end_loop = true
    err = auto_cast nerr
    fmt.println("ERROR: Failed to connect to the gateway server")
    return
  }

  lnc.state = .ConnectingToServer
  lnc.state_transition_time = time.now()

  return
}

_concurrent_initialize :: proc(state: rawptr) {
  lnc: ^LauncherData = auto_cast state

  sync.mutex_lock(&lnc.alt_sync)
  lnc.alt_state = .Running
  sync.mutex_unlock(&lnc.alt_sync)
  defer {
    sync.mutex_lock(&lnc.alt_sync)
    lnc.alt_state = .Stopped
    // fmt.println("Concurrent thread stopped:", cast(^ExistingFileSearch)&lnc.alt_data)
    sync.mutex_unlock(&lnc.alt_sync)
    // fmt.println("Concurrent thread ended")
  }

  launcher_files := [?]string { "launcher" }
  _develop_client_file_list(lnc, auto_cast &lnc.alt_data, launcher_files[:], os.get_current_directory())
}

_develop_client_file_list :: proc(lnc: ^LauncherData, efs: ^ExistingFileSearch, launcher_files: []string,
  client_root_directory: string, sub_directory: string = "") {

  files: []os.File_Info
  {
    read_directory: string
    if len(sub_directory) == 0 {
      read_directory = client_root_directory
    } else {
      read_directory = cu.apply_relative_path(client_root_directory, sub_directory)
    }

    // Open the current client_root_directory
    dir, errno := os.open(read_directory)
    if errno != 0 {
      fmt.println("open dir problem:", errno)
      libc.perror("open dir problem")
      lnc.alt_err = .FailedToOpenCurrentDirectory
      return
    }
  
    // Read the client_root_directory
    files, errno = os.read_dir(dir, 16)
    if errno != 0 {
      fmt.println("read dir problem:", errno)
      libc.perror("read dir problem")
      lnc.alt_err = .FailedToReadCurrentDirectory
      return
    }
  }
  // defer { TODO -- EBADF all the time. I don't think you need to close a directory (not a regular file, but a special one)
  //   // Close the directory
  //   errno = os.close(dir)
  //   if errno != 0 {
  //     fmt.println("close dir problem:", errno)
  //     libc.perror("close dir problem")
  //     err = auto_cast errno
  //   }
  // }

  // Generate the manifest
  // gsrv.game_files = make_map(map[u32]^GameFile, 64)
  for file in files {
    if file.is_dir {
      // Recurse into subdirectory
      recurse_sub_dir: string
      if sub_directory == "" {
        recurse_sub_dir = file.name
      } else {
        recurse_sub_dir, aerr := strings.concatenate({sub_directory, "/", file.name}, context.temp_allocator)
        if aerr != .None {
          fmt.println("ERROR: Failed to concatenate directory path:", client_root_directory, ",", file.name)
          lnc.alt_err = .AllocationFailed
          return
        }
      }
      _develop_client_file_list(lnc, efs, launcher_files[:], client_root_directory, recurse_sub_dir)
      continue
    }

    // Exclude Launcher Files -- TODO -- This is a hack
    if file.name == "launcher" do continue

    cgf: ClientGameFile
    cgf.size = auto_cast file.size

    if len(sub_directory) == 0 {
      cgf.relative_path = file.name
    } else {
      aerr: mem.Allocator_Error
      cgf.relative_path, aerr = strings.concatenate({sub_directory, "/", file.name}, context.allocator)
      if aerr != .None {
        fmt.println("ERROR: Failed to concatenate relative path:", sub_directory, ",", file.name)
        lnc.alt_err = .AllocationFailed
        return
      }
    }

    // Read the file
    data, success := os.read_entire_file(file.fullpath)
    if !success {
      fmt.println("ERROR] Could not read file:", file.fullpath)
      lnc.alt_err = .FailedToReadDirectoryFile
      return
    }

    // Hash the file
    hash_bytes := md5.hash_bytes(data)
    cgf.data_hash = (cast(^u128)&hash_bytes[0])^

    append(&efs.current_file_list, cgf)
    // fmt.println(args={"--", cgf}, sep="")
  }
}

_update_launcher_connecting_to_server :: proc(lnc: ^LauncherData) -> (do_end_loop: bool, err: LauncherError) {
  // Check for connection
  switch lnc.net.status {
    case .Connecting:
      if time.diff(lnc.state_transition_time, time.now()) > time.Second * auto_cast (lnc.state_retry_count * 5) {
        // Couldn't connect to server
        fmt.println("Couldn't connect to server")
        // do_end_loop = true
        lnc.state_retry_count += 1
      }
    case .Connected:
      fmt.println("Connected to gateway")

      // Update the state
      lnc.state = .RetrievingServiceInfo
      lnc.state_transition_time = time.now()
      lnc.state_retry_count = 0

      // Reset the Service Info State
      lnc.service.status = cn.ServiceStatus {}
      lnc.service.retry_count = 0
      lnc.service.retry_time = time.time_add(time.now(), time.Second * 4)

      // Reset the Manifest State
      lnc.manifest.remote_version = cg.GameVersion {}
      clear_dynamic_array(&lnc.manifest.remote_file_list)
      lnc.manifest.verification_status = .CollectingCurrentFileList
      lnc.manifest.retry_time = time.time_add(time.now(), time.Second * 4)
      lnc.manifest.retry_count = 0

      // Request remote info
      res := cn.send_packet(lnc.net.server, .Reliable, cn.DataSignal{
        signal_type = .ServiceStatusAndGameClientManifestRequest,
      })
      if res != .Success {
        fmt.println("ERROR] Failed to send packet")
        err = .NetworkError
        do_end_loop = true
        return
      }

    case .Uninitialized, .Idle, .Initializing, .Initialized, .Disconnecting, .Disconnected:
      // TODO -- handle these
    case .Shutdown, .EndedDueToError:
      fmt.println("TODO -- Handle ended netcli:", lnc.net.status)
      do_end_loop = true
      err = .NetworkError
      return
    case:
      fmt.println("TODO unhandled net.status:", lnc.net.status)
  }
  return
}

_update_launcher_retrieving_service_info :: proc(lnc: ^LauncherData) -> (do_end_loop: bool, err: LauncherError) {
  // Check for connection
  if lnc.net.status != .Connected {
    // Do nothing for now
    // TODO -- handle this
    // fmt.println("Warning: not connected to gateway")
    return
  }

  // Game File Verification
  do_end_loop = _update_game_file_verification(lnc) or_return
  if do_end_loop do return

  // Service Status
  if time.diff(time.now(), lnc.service.retry_time) <= 0 {
    if lnc.service.retry_count >= 8 {
      fmt.println("ERROR] Failed to retrieve a good service status")
      fmt.println("--game_servers:", lnc.service.status.game_servers)
      fmt.println("--authentication_servers:", lnc.service.status.authentication_servers)
      do_end_loop = true
      err = .NotYetDetailed
      return
    }

    // fmt.println("Retrying service status request")
    res := cn.send_packet(lnc.net.server, .Reliable, cn.DataSignal{
      signal_type = .ServiceStatusRequest,
    })
    if res != .Success {
      fmt.println("ERROR] Failed to send packet")
      err = .NetworkError
      do_end_loop = true
      return
    }
    lnc.service.retry_count += 1
    lnc.service.retry_time = time.time_add(time.now(), time.Second * auto_cast clamp(lnc.service.retry_count * 2, 4, 16))
  }

  // Transition Condition
  if lnc.service.status.game_servers == .Available && lnc.service.status.authentication_servers == .Available &&
      lnc.manifest.verification_status == .Verified {

    // fmt.println("Launching the game")
    lnc.launch_client_on_exit = true
    do_end_loop = true
    return

    // // Move to auto-launching
    // pid, errno := os.fork()
    // if errno != 0 {
    //   fmt.println("ERROR] Failed to fork:", errno)
    //   err = .NotYetDetailed
    //   return
    // }
    // if pid == 0 {
    //   // Child
    //   // path: cstring = "./client"
    //   // args: []cstring = { ".." }
    //   // intrinsics.syscall(unix.SYS_execve, uintptr(rawptr(path)), uintptr(rawptr(&args[0])), uintptr(0))
    //   // system("gnome-terminal -e \"./client ..\"")
      
    // } else {
    //   // Close the Parent
    //   do_end_loop = true
    //   return
    // }
  }

  return
}

_update_game_file_verification :: proc(using lnc: ^LauncherData) -> (do_end_loop: bool, err: LauncherError) {
  using mf: ^ManifestInfo = &lnc.manifest

  if mf.verification_status == .CollectingCurrentFileList {
    // Attempt to verify current game files
    sync.mutex_lock(&lnc.alt_sync)
    if lnc.alt_state == .Stopped {
      efs: ^ExistingFileSearch = auto_cast &lnc.alt_data
      // fmt.println("Game_Files:")
      // for file, i in efs.current_file_list {
      //   fmt.println("  ", i, ":", file.relative_path, ":", file.size, ":", file.data_hash)
      // }
      
      // Collection has finished
      mf.verification_status = .AwaitingRemoteManifest
      // fmt.println(".AwaitingRemoteManifest")
    }
    sync.mutex_unlock(&lnc.alt_sync)
  }

  // Check for remote manifest
  if mf.verification_status == .AwaitingRemoteManifest {
    if mf.remote_version == {0, 0, 0} {
      // Look to retry request
      if mf.retry_count >= 4 {
        fmt.println("ERROR] Failed to retrieve the game client manifest")
        do_end_loop = true
        err = .NotYetDetailed
        return
      }

      if time.diff(time.now(), mf.retry_time) <= 0 {
        // fmt.println("Retrying game client manifest request")
        res := cn.send_packet(lnc.net.server, .Reliable, cn.DataSignal{
          signal_type = .GameClientManifestRequest,
        })
        if res != .Success {
          fmt.println("ERROR] Failed to send packet")
          err = .NetworkError
          do_end_loop = true
          return
        }
        mf.retry_count += 1
        mf.retry_time = time.time_add(time.now(), time.Second * auto_cast clamp(mf.retry_count * 2, 0, 16))
      }
    } else {
      // Manifest received -> Move on
      mf.verification_status = .VerifyingClientFiles
      // fmt.println(".VerifyingClientFiles")

      mf.retry_count = 0
      mf.retry_time = time.time_add(time.now(), time.Minute * 30)
    }
  }

  if mf.verification_status == .DownloadingGameFiles {
    if mf.transfer.bytes_downloaded == mf.transfer.file_info.size {
      transfer_data := mf.transfer.data[0:mf.transfer.bytes_downloaded]
      // File has finished downloading
      dl_duration := time.diff(mf.transfer.start_time, time.now())

      // Verify File Hash
      hash_bytes := md5.hash_bytes(transfer_data)
      dlf_hash := (cast(^u128)&hash_bytes[0])^

      if dlf_hash != mf.transfer.file_info.data_hash {
        fmt.println("ERROR] Failed to verify downloaded file")
        fmt.println("Downloaded file:", mf.transfer.file_info.relative_path)
        fmt.println("dlf_hash:", dlf_hash)
        fmt.println("mf.transfer.file_info.data_hash:", mf.transfer.file_info.data_hash)
        do_end_loop = true
        err = .NotYetDetailed
        return
      }

      // Copy the file to the game directory
      success := _write_client_file(mf.transfer.file_info.relative_path, transfer_data)
      if !success {
        fmt.println("ERROR] Failed to write file to disk")
        fmt.println(args={"Downloaded file: '", mf.transfer.file_info.relative_path, "'",}, sep="")
        do_end_loop = true
        err = .NotYetDetailed
        return
      }

      if mf.transfer.file_info.relative_path == "client" {
        // Make the client executable
        cstr := strings.clone_to_cstring(mf.transfer.file_info.relative_path)
        // defer delete_cstring(cstr)
        res := intrinsics.syscall(unix.SYS_chmod, uintptr(rawptr(cstr)), uintptr(0o755))
        if res != 0 {
          fmt.println("ERROR] Failed to make client executable")
          do_end_loop = true
          err = .NotYetDetailed
          return
        }
      }

      // Update the file in the local client file list
      efs: ^ExistingFileSearch = auto_cast &lnc.alt_data
      updated_existing_file := false
      for i in 0..<len(efs.current_file_list) {
        if efs.current_file_list[i].relative_path == mf.transfer.file_info.relative_path {
          // Found
          efs.current_file_list[i].size = mf.transfer.bytes_downloaded
          efs.current_file_list[i].data_hash = dlf_hash
          updated_existing_file = true
          break
        }
      }
      if !updated_existing_file {
        // Create a new entry
        append(&efs.current_file_list, ClientGameFile {
          relative_path = mf.transfer.file_info.relative_path,
          size = mf.transfer.bytes_downloaded,
          data_hash = dlf_hash,
        })
      }

      // Update state
      mf.verification_status = .VerifyingClientFiles
      // fmt.println(".VerifyingClientFiles")
      dl_speed: f32 = cast(f32) mf.transfer.bytes_downloaded / (cast(f32)dl_duration / cast(f32)time.Second)
      fmt.println(args={"Downloaded file:", mf.transfer.file_info.relative_path, " (", mf.bytes_downloaded, " bytes @ ",
        cast(int)dl_speed, "b/s)"}, sep="")
      return
    }
  }

  if mf.verification_status == .VerifyingClientFiles {
    local: []ClientGameFile = (cast(^ExistingFileSearch) &lnc.alt_data).current_file_list[:]
    remote: []RemoteGameFile = mf.remote_file_list[:]
    
    // Search for any updates
    verified := true
    for rf in remote {
      // Find the local file
      lf: ^ClientGameFile
      for i in 0..<len(local) {
        if local[i].relative_path == rf.relative_path {
          lf = &local[i]
          break
        }
      }

      if lf == nil || lf.data_hash != rf.data_hash {
        // File is missing
        if lf == nil {
          fmt.println(args={"Downloading missing file:'", rf.relative_path, "' id:", rf.remote_id}, sep="")
          // fmt.println("  local:", lf)
          // fmt.println("  remote:", rf)
        } else {
          fmt.println(args={"Downloading updated file:'", rf.relative_path, "' id:", rf.remote_id}, sep="")
          // fmt.println("  local:", lf)
          // fmt.println("  remote:", rf)
        }

        // Resize the file_download data array
        aerr: mem.Allocator_Error
        if mf.transfer.data == nil || len(mf.transfer.data) < auto_cast rf.size {
          if mf.transfer.data != nil do delete_slice(mf.transfer.data)

          mf.transfer.data, aerr = make([]u8, rf.size)
          if aerr != .None {
            fmt.println("ERROR] Failed to allocate memory for file download")
            err = .NotYetDetailed
            do_end_loop = true
            return
          }
        }

        // Update the state
        mf.verification_status = .DownloadingGameFiles
        // fmt.println(".DownloadingGameFiles")
        mf.transfer.file_info = rf
        mf.transfer.bytes_downloaded = 0
        mf.transfer.start_time = time.now()

        // Request the file
        request_file_download(lnc, rf.remote_id) or_return
        verified = false
        break
      } else {
        // File exists and is up-to-date
        // Do nothing
        // fmt.println(" -- File is up to date:", rf.relative_path)
      }
    }

    if verified {
      // All files are verified
      // Update the state
      mf.verification_status = .Verified
      // fmt.println(".Verified")
      mf.retry_count = 0
      mf.retry_time = time.time_add(time.now(), time.Minute * 30)
      fmt.println(args={"Game Client Is Up To Date", " (", mf.remote_version.major, ".", mf.remote_version.minor, ".",
        mf.remote_version.patch, ")"}, sep="")

      // Cleanup
      efs: ^ExistingFileSearch = auto_cast &lnc.alt_data
      delete_dynamic_array(efs.current_file_list)
    }
  }

  return
}

@(private) _write_client_file :: proc(path: string, data: []u8) -> bool {
  // Ensure the directory exists
  okay := cu.ensure_parent_directory_exists(path)

  // Mode
  mode := 0
	when os.OS == .Linux || os.OS == .Darwin {
    // if path == "client" {
    //   // mode = os.S_IRWXO | os.S_IRWXG | os.S_IRWXU
    //   mode = os.S_IRWXU | os.S_IRGRP | os.S_IROTH
    // } else {
      // NOTE(justasd): 644 (owner read, write; group read; others read)
      mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
    // }
	}

  // Open the file
  file: os.Handle
  err: os.Errno
  file, err = os.open(path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, mode)
  if err != 0 {
    fmt.println("ERROR] Failed to open file for writing")
    fmt.println("  path:", path)
    fmt.printf("  mode: %o\n", mode)
    fmt.println("  error:", cu.get_errno_string(err))
    return false
  }
  defer os.close(file)

  // Write the data
	_, write_err := os.write(file, data)
  if write_err != 0 {
    fmt.println("ERROR] Failed to write file")
    fmt.println("  path:", path)
    fmt.printf("  mode: %o\n", mode)
    fmt.println("  error:", cu.get_errno_string(write_err))
  }

	return write_err == 0
}

_update_launcher_client_verified :: proc(lnc: ^LauncherData) -> (do_end_loop: bool, err: LauncherError) {
  // Auto-Launch
  // if lnc.state_transition_time

  return
}

_update_input :: proc(using lnc: ^LauncherData) -> (do_end_loop: bool, err: LauncherError) {
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
        handled, verr := vig.handle_gui_event(lnc.gui, &event)
        if !handled {
          // Send the event to the world
          // input_event_world(lnc, event) or_return
        }
        // fmt.println(".TEXTINPUT:", event.text.text)
      case .TEXTEDITING:
        // Do not know what to do with this
        // if lnc.historical_frame_count > 1000 {
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

_on_packet_received :: proc(packet: ^cn.PacketData, state: rawptr) {
  lnc: ^LauncherData = auto_cast state
  sync.mutex_lock(&lnc.state_sync)
  defer sync.mutex_unlock(&lnc.state_sync)

  // fmt.println("Received packet:", packet.data_type)

  #partial switch packet.data_type {
    case .ServiceStatus:
      _receive_service_status(lnc, auto_cast &packet.data)
    case .GameClientManifest:
      _receive_game_client_manifest(lnc, auto_cast &packet.data)
    case .GameClientFileTransfer:
      _receive_game_client_file_transfer(lnc, auto_cast &packet.data)
    case:
      fmt.println("Unhandled packet type:", packet.data_type)
  }
}

_receive_service_status :: proc(lnc: ^LauncherData, ss: ^cn.ServiceStatus) {
  // fmt.println("Service Status Received:", ss)

  // Set
  lnc.service.status = ss^

  if lnc.state != .RetrievingServiceInfo {
    fmt.println("TODO -- Handle unexpected ServiceStatus during state:", lnc.state)
    lnc.state = .FatalError
    return
  }
  // if ss.authentication_servers != .Available {
  //   return
  // }
  // if ss.game_servers != .Available {
  //   // fmt.println("Game servers are not Available")
  //   // lnc.state = .FatalError
  //   return
  // }

  // sb.received_good_service_status = true

  // fmt.println("TODO Next Stage")
  // lnc.state = .FatalError
  return
  // // TODO -- Start Game
  // request_game_server_authentication(lnc)
}

_receive_game_client_manifest :: proc(lnc: ^LauncherData, gcm: ^cn.GameClientManifest) {
  // Delay the manifest retry time for a significant period
  lnc.manifest.retry_time = time.time_add(time.now(), time.Hour * 1000)

  // fmt.println("Game Client Manifest Received:", gcm)
  if len(gcm.file_list) < 1 {
    fmt.println("ERROR -- Handle empty Game Client Manifest file list!!!")
    lnc.state = .FatalError
    return
  }

  // Ensure file_list is nil, this is not to be referenced as it is owned by the packet and should not be necessary
  lnc.manifest.remote_version = gcm.version
  if lnc.manifest.remote_file_list != nil {
    // Clear the remote file list and recreate it
    clear_dynamic_array(&lnc.manifest.remote_file_list)
  }

  // Decode and store the file list
  offset: int = 0
  for offset < len(gcm.file_list) {
    id, rpath, size, data_hash := cn.decode_manifest_file_from_file_list(&lnc.strbld, auto_cast &gcm.file_list[0], &offset)
    // fmt.println("gcm.file:", id, "-", rpath, "-", size, "-", data_hash)
    cloned_path, aerr := strings.clone(rpath)
    if aerr != .None {
      fmt.println("ERROR -- Failed to clone path:", rpath, " AllocatorError:", aerr)
      lnc.state = .FatalError
      return
    }
    append(&lnc.manifest.remote_file_list, RemoteGameFile {
      _cgf = ClientGameFile {
        relative_path = cloned_path,
        size = size,
        data_hash = data_hash,
      },
      remote_id = id,
    });
  }
}

_receive_game_client_file_transfer :: proc(lnc: ^LauncherData, gcft: ^cn.GameClientFileTransfer) {
  if lnc.state != .RetrievingServiceInfo {
    fmt.println("TODO -- Handle unexpected GameClientFileTransfer during state:", lnc.state)
    lnc.state = .FatalError
    return
  }
  if lnc.manifest.verification_status != .DownloadingGameFiles {
    fmt.println("TODO -- Handle unexpected GameClientFileTransfer")
    fmt.println("-- verification_status:", lnc.manifest.verification_status)
    lnc.state = .FatalError
    return
  }

  // Verify
  if gcft.id != lnc.manifest.transfer.file_info.remote_id {
    fmt.println("TODO -- Handle unexpected GameClientFileTransfer")
    fmt.println("--gcft.id:", gcft.id, "current_downloading_file_id:", lnc.manifest.transfer.file_info.remote_id)
    lnc.state = .FatalError
  }

  // Handle File Transfer
  if gcft.offset != lnc.manifest.transfer.bytes_downloaded {
    fmt.println("TODO -- Handle unexpected GameClientFileTransfer")
    fmt.println("--gcft.offset:", gcft.offset, "current_downloaded_bytes:", lnc.manifest.transfer.bytes_downloaded)
    lnc.state = .FatalError
  }

  if len(gcft.data) < 1 {
    fmt.println("TODO -- Handle unexpected GameClientFileTransfer")
    fmt.println("--gcft.data is empty")
    lnc.state = .FatalError
  }

  // Copy the data
  mem.copy(&lnc.manifest.transfer.data[lnc.manifest.transfer.bytes_downloaded], auto_cast &gcft.data[0],
    len(gcft.data))
  lnc.manifest.transfer.bytes_downloaded += auto_cast len(gcft.data)
}

request_file_download :: proc(using lnc: ^LauncherData, file_id: u32) -> LauncherError {
  // Send a message to the server
  res := cn.send_packet(lnc.net.server, .Reliable, cn.DetailedDataSignal {
      signal_type = .GameClientFileRequest,
      detail = file_id,
    })
  if res != .Success do return .NetworkError

  return .Success
}