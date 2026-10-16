# Use Focused Break

## Set the rhythm

The three controls below the timer share the same layout:

| Control | Meaning |
| --- | --- |
| Focus time | Work duration, from 2 to 120 minutes |
| Break time | Planned rest duration |
| End break after | Protected seconds before Pause and End are available, from 5 to 300 |

The protected interval starts with each break. If it exceeds the selected break length, the break is extended to cover it. Quitting always remains available. The overlay does not block mouse clicks or lock the computer.

Press **Start focus**. The desktop stays clear during focus. The reminder grows in during a break, moves at your selected size, and shrinks near the end. When the break finishes, the app comes forward with the next focus duration. Starting again is your choice.

## Choose your break appearance

**Visual** selects Black hole, Have a break, or My image. If no custom image exists, My image opens a file picker. Uploads are copied into the app's local storage, so moving or deleting the original does not break the reminder. Replacing an image saves the new one; Remove returns to the bundled animation. Switching visuals retains the uploaded image.

**Size** offers Small, Medium, and Large. Fine-tuned sizes may not match any of those three buttons.

**Motion & distortion** groups two independent choices:

- **Distort desktop** bends captured screen content around the visual. It needs optional screen-recording permission.
- **Reduce motion** stops travel and rim animation and displays the first GIF frame. Growth and shrink transitions still occur.

**Fine-tune** reveals presets and sliders for size, gravity, movement range, movement speed, and field reach. The black hole also has rim brightness and width controls. Selecting a preset changes multiple effect values, including size. Default restores the standard configuration.

## Preview before a session

Expand **Preview**. Live desktop uses your screen; Grid and Space are generated backgrounds. Play/pause controls preview animation, while restart resets the preview cycle. Pausing preview animation does not stop live desktop capture; collapse Preview to stop its capture stream.

**Test on desktop · 10s** immediately shows the real effect and closes automatically after ten seconds. It is available while no focus session is running and can be stopped early. This is separate from the protected interval of an actual break.

## Menu bar, sleep, and shortcuts

Closing the main window leaves the timer running. Use the pause-shaped menu-bar icon to reopen it, pause/resume, take a break early, end the session, or quit. Sleep pauses the timer; resume manually after waking. Sessions do not resume after quitting the app.

While app controls have keyboard focus, Return starts/pauses/resumes, Command-P controls the session, Command-B takes a break, and Command-period ends it. Escape ends a session when available. Protection still applies. These are not global hotkeys.

The original URL scheme is retained for Shortcuts and launchers:

| URL | Action |
| --- | --- |
| `eventhorizon://show` | Open the main window |
| `eventhorizon://start` | Start a session if idle |
| `eventhorizon://pause` | Pause |
| `eventhorizon://resume` | Resume |
| `eventhorizon://break` | Take a full break early |
| `eventhorizon://stop` | Stop, subject to break protection |
| `eventhorizon://demo` | Run the ten-second desktop test |

Run the app once to register the URL scheme. In macOS Shortcuts, use **Open URLs** with one of these values.
