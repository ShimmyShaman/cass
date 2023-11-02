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

SourceEditor :: struct {
  using _ctrlnfo: vig._ControlInfo,

  plain_text: string,

  font: vi.FontResourceHandle,
  font_color, hint_font_color: vi.Color,

  background_color: vi.Color,
}

create_source_editor :: proc(parent: ^vig.Control) -> (se: ^SourceEditor, err: vi.Error) {
  se = new(SourceEditor)

  // Set the control info
  se.ctype = .ExclusiveMax
  se.id = "Source Editor"
  se.visible = true

  se._delegates.determine_layout_extents = vig.determine_layout_extents
  se._delegates.render_control = _render_source_editor
  se._delegates.update_control_layout = vig.update_control_layout
  se._delegates.destroy_control = _destroy_source_editor_control
  se._delegates.handle_gui_event = _handle_source_editor_gui_event

  // se.properties = { .TextRestrained }
  // se.bounds = vi.Rectf{0.0, 0.0, 80.0, 20.0}
  // se._ctrlnfo._layout
  // se.bounds.left = 0.0
  // se.bounds.top = 0.0
  // se.bounds.right = 80.0
  // se.bounds.bottom = 20.0

  // Default Settings
  // se._layout.min_width = 8;
  // se._layout.min_height = 8;
  se._layout.margin = { 1, 1, 1, 1 }

  // Set the se info
  se.plain_text = ""
  se.font = 0
  se.font_color = vi.COLOR_White
  se.background_color = vi.COLOR_DarkSlateGray
  // se.clip_text_to_bounds = false

  vig.set_control_requires_layout_update(auto_cast se)

  vig._add_control(parent, auto_cast se) or_return

  return
}

@(private) _render_source_editor :: proc(using grc: ^vig.GUIRenderContext, control: ^vig._ControlInfo) -> (err: vi.Error) {
se: ^SourceEditor = auto_cast control

// fmt.println("Rendering se: ", se.font)
se_font := se.font if se.font != auto_cast 0 else gui_root.default_font
// fmt.println("se: ", se.font, "&& se_font: ", se_font)

if se.background_color.a > 0.0 {
  // fmt.println("extents=", se.determined_width_extent, "x", se.determined_height_extent)
  // fmt.println("se.bounds=", se.bounds)
  vi.stamp_colored_rect(rctx, stamprr, &se.bounds, &se.background_color) or_return
}

// if se.plain_text == "" {
//   if se.hint_text != "" {
//     vi.stamp_text(rctx, stamprr, se_font, se.hint_text, se.bounds.x, se.bounds.y + se.bounds.height,
//       &se.hint_font_color) or_return
//   }
// } else if se.font_color.a > 0.0 {
//   // fmt.print("Rendering text:", se.plain_text, "at:", se.bounds.x, "x", se.bounds.y + se.bounds.height)
//   // fmt.println(" with color:", se.font_color)
//   vi.stamp_text(rctx, stamprr, se_font, se.plain_text, se.bounds.x, se.bounds.y + se.bounds.height,
//     &se.font_color) or_return
// }

return
}

@(private) _handle_source_editor_gui_event :: proc(control: ^vig.Control, event: ^sdl2.Event) -> (handled: bool, err: vi.Error) {
se: ^SourceEditor = auto_cast control

// Check
mouse_is_over := vig.is_mouse_over_control(control)
has_focus := vig.is_focused(control)
if !mouse_is_over && !has_focus {
  return
}

#partial switch event.type {
  case .KEYDOWN:
    #partial switch event.key.keysym.sym {
      // se.plain_text = se.plain_text[0:se.plain_text.len - 1]
      // set_control_requires_layout_update(auto_cast se)
      // handled = true
    case:
      fmt.println("_handle_source_editor_gui_event: Unhandled KEYDOWN:", event.key.keysym.sym)
      err = .NotYetImplemented
      return
      }
  
  case:
    fmt.println("_handle_source_editor_gui_event: Unhandled event type:", event.type)
    err = .NotYetImplemented
    return
}

// } else if event.type == sdl2.EVENT_TEXTINPUT {
//   se.plain_text += event.plain_text.plain_text
//   set_control_requires_layout_update(auto_cast se)
//   handled = true
// }

return
}

// @(private) _determine_source_editor_extents :: proc(gui_root: ^vig.GUIRoot, control: ^vig.Control, restraints: vig.LayoutExtentRestraints) -> vi.Error {
//   se: ^SourceEditor = auto_cast control

//   se_font := se.font if se.font != auto_cast 0 else gui_root.default_font

//   text_width, text_height: f32
//   if len(se.plain_text) > 0 {
//     text_width, text_height = vi.determine_text_display_dimensions(gui_root.vctx, se_font, se.plain_text) or_return
//   } else {
//     // text_width, text_height = vi.determine_text_display_dimensions(gui_root.vctx, se_font, se.hint_text) or_return
//     // fmt.println("Hint text:", se.hint_text, "has dimensions:", text_width, "x", text_height)
//   }

//   return vig.determine_text_restrained_control_extents(gui_root, control, restraints, text_width, text_height)
// }

@(private) _destroy_source_editor_control :: proc(ctx: ^vi.Context, control: ^vig.Control) {
  se: ^SourceEditor = auto_cast control
  if se.font != 0 do vi.destroy_font(ctx, se.font)
}