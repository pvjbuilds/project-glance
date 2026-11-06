---
name: Project Glance
description: A compact macOS project overview
colors:
  shell: "#161616"
  card: "#242424"
  card-border: "rgba(255, 255, 255, 0.1)"
typography:
  heading:
    fontFamily: "system-ui"
    fontSize: "17px"
    fontWeight: 600
  state:
    fontFamily: "system-ui"
    fontSize: "14px"
    fontWeight: 600
  body:
    fontFamily: "system-ui"
    fontSize: "12px"
  label:
    fontFamily: "system-ui"
    fontSize: "10px"
    fontWeight: 700
rounded:
  card: "10px"
spacing:
  shell: "16px"
  card: "12px"
  gap: "8px"
---

# Design System: Project Glance

## Overview

A compact native macOS menu-bar popover follows the user-selected screenshot's dark shell, inset sections and quiet footer. The utility shown in the reference supplies no branding or unrelated controls. The product name is provisional. Concrete token primitives are in the frontmatter; the `.impeccable/design.json` sidecar holds supplemental metadata.

## Colors

Charcoal shell and lighter cards provide depth; muted grey distinguishes supporting information. The native system blue marks saved completed milestones and adapts to macOS. Cards use a subtle white border.

## Typography

Use the macOS system font. The heading identifies the app; the state uses stronger emphasis. Small bold uppercase labels organize sections; body text remains readable and wraps.

## Layout

The content view is 400 by 570 points with a fixed header and footer. Cards scroll between them. Long content must remain accessible without covering controls.

## Shapes

Inset cards use the card radius and a thin border. The native popover supplies the outer rounded material and menu-bar anchor.

## Components

The picker identifies each project by name and stable ID. Nested milestone branches use keyboard-accessible disclosure controls and 14-point indentation per level. Completed milestone counts refer to top-level milestones only. Milestones show a blue checked square only when stored completion is true; pending items use an empty square. Each is display-only with a checkbox accessibility role and value. Legacy and invalid data have explicit states. Settings and Quit use native buttons with SF Symbols.

## 7 November 2026 selected refinement
Direction 3, Status board, selected by Praj with tighter spacing. Use flat sections on the charcoal shell, aligned label/value rows, thin dividers and six-point summary spacing. Health uses semantic color; pending/completed milestone state remains explicit. Goal and full status remain accessible in Details; raw timestamp, project and session identifiers sit behind Technical details. Show localized short saved date and saver label in a fixed footer; stale, clock mismatch and unavailable warnings remain explicit. Friendly project names are disambiguated with stable IDs only for duplicates. The fixed 400 by 570-point native surface and nested disclosure behavior remain. This dated section supersedes the earlier overview and milestone card styling.
