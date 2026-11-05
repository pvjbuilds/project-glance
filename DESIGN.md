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

A compact native macOS menu-bar popover follows the user-selected screenshot's dark shell, inset sections and quiet footer. The utility shown in the reference supplies no branding or unrelated controls. The product name is provisional.

## Colors

Charcoal shell and lighter cards provide depth; muted grey distinguishes supporting information. The native system blue marks saved completed milestones and adapts to macOS. Cards use a subtle white border.

## Typography

Use the macOS system font. The heading identifies the app; the state uses stronger emphasis. Small bold uppercase labels organize sections; body text remains readable and wraps.

## Layout

The content view is 380 by 510 points with a fixed header and footer. Cards scroll between them. Long content must remain accessible without covering controls.

## Shapes

Inset cards use the card radius and a thin border. The native popover supplies the outer rounded material and menu-bar anchor.

## Components

The picker identifies each project by name and stable ID. Milestones show a blue checked square only when stored completion is true; pending items use an empty square. Each is display-only with a checkbox accessibility role and value. Legacy and invalid data have explicit states. Settings and Quit use native buttons with SF Symbols.
