# LocalKeyRemapper

**A native, privacy-first, security-first and accessibility-first keyboard remapper for macOS.**

LocalKeyRemapper lets you temporarily remap keyboard keys on macOS through custom profiles, configurable rules, modifier support, bidirectional mappings, per-rule exceptions and fast menu bar controls.

Everything runs locally on your Mac.

No accounts. No analytics. No telemetry. No cloud services. No Internet connection. No keystroke history.

> **Accessibility first. Privacy first. Security first. Native performance.**

---

## Download, build and run LocalKeyRemapper

LocalKeyRemapper can be obtained in two different ways:

| What you want to do                 | Recommended option                              |
| ----------------------------------- | ----------------------------------------------- |
| Use LocalKeyRemapper immediately    | Download the ready-to-use release               |
| Inspect or modify the source code   | Download or clone the repository                |
| Contribute to the project           | Clone the repository with Git                   |
| Build the application independently | Clone or download the source code and use Xcode |

Both the source code and the packaged application are distributed through the official LocalKeyRemapper GitHub repository.

> **Only download LocalKeyRemapper from the official repository or its Releases page.**

---

### Option 1 — Download the ready-to-use application

This is the recommended option for most users.

The packaged release is already compiled and does not require Xcode or any programming knowledge.

[Download the latest LocalKeyRemapper release](https://github.com/Alessandro-Giuriati/LocalKeyRemapper/releases/latest)

To install it:

1. Open the latest release page.
2. Find the **Assets** section.
3. Download the LocalKeyRemapper `.dmg` file.
4. Open the downloaded disk image.
5. Drag `LocalKeyRemapper.app` into the `Applications` folder.
6. Eject the disk image.
7. Open LocalKeyRemapper from the `Applications` folder.
8. Grant Accessibility permission when macOS requests it.

Do not download these files when you want the ready-to-use application:

```text
Source code (zip)
Source code (tar.gz)
```

Those files contain the project’s source code, not the compiled macOS application.

#### Accessibility permission

LocalKeyRemapper needs explicit Accessibility permission because keyboard-event modification is a protected macOS capability.

Permission can be managed from:

```text
System Settings
→ Privacy & Security
→ Accessibility
```

If LocalKeyRemapper does not appear in the Accessibility list:

1. Click the `+` button at the bottom of the list.
2. Select:

```text
/Applications/LocalKeyRemapper.app
```

3. Add the application.
4. Enable the switch next to LocalKeyRemapper.
5. Completely quit and reopen the application if required.

Removing or disabling LocalKeyRemapper in this list prevents it from performing keyboard remapping.

---

#### Verify the downloaded application

Each official release may include a SHA-256 checksum for the downloadable disk image.

A checksum allows you to verify that the file on your Mac is identical to the file published with the release.

After downloading the `.dmg`, open Terminal and run:

```bash
cd ~/Downloads
shasum -a 256 LocalKeyRemapper-*.dmg
```

Terminal will display a value similar to:

```text
5c7d...example...81a2  LocalKeyRemapper-1.0.0.dmg
```

Compare the complete value with the SHA-256 checksum shown in the corresponding release notes.

The two values must match exactly.

A matching checksum confirms that the downloaded file has not changed since the checksum was generated. It does not replace the need to download the application from the official repository and review the project’s security model.

---

#### Why download the compiled application?

The ready-to-use release is the most practical choice when you simply want to use LocalKeyRemapper.

Advantages include:

* no Xcode installation;
* no development environment configuration;
* no manual compilation;
* no programming knowledge required;
* faster installation;
* a packaged `.app` designed to be placed directly in the `Applications` folder;
* the exact application package distributed with the selected release.

Choose the compiled release when:

* you want to use the application rather than develop it;
* you trust the official project repository and release process;
* you do not need to modify the source code;
* you want the simplest installation procedure.

---

#### Why might you avoid the compiled application?

A compiled application cannot be inspected in the same direct and readable form as its Swift source code.

When you download a precompiled binary, you must place some trust in:

* the project maintainer;
* the release account;
* the build environment;
* the packaging process;
* the integrity of the downloaded file.

The source code remains publicly inspectable, but reading the source code alone does not independently prove that a particular downloaded binary was produced from exactly that source code.

You may therefore prefer to build LocalKeyRemapper yourself when:

* you want maximum control over the build;
* you want to inspect the code before execution;
* you want to modify the application;
* you want to use Xcode’s debugging and analysis tools;
* you do not want to rely exclusively on a precompiled release;
* you are testing a specific branch, tag or commit.

Building from source increases transparency and control, but it also requires more time, disk space and technical knowledge.

---

### Option 2 — Download the source code

The complete LocalKeyRemapper source code is available from the repository:

[View the LocalKeyRemapper source code](https://github.com/Alessandro-Giuriati/LocalKeyRemapper)

There are two main ways to obtain it.

---

#### Download the source code as a ZIP file

This is the simplest method when you want to inspect or build the source code without using Git.

1. Open the repository.
2. Click the green **Code** button.
3. Select **Download ZIP**.
4. Extract the downloaded archive.
5. Open the extracted `LocalKeyRemapper` folder.
6. Open:

```text
LocalKeyRemapper.xcodeproj
```

The ZIP file is a snapshot of the repository at the moment it was downloaded.

It does not include the complete Git history and cannot be updated through `git pull`.

To obtain a newer version later, you must download a new ZIP archive or start using Git.

---

#### Clone the repository with Git

Cloning is recommended for development, contribution and long-term source-code management.

Open Terminal and run:

```bash
git clone https://github.com/Alessandro-Giuriati/LocalKeyRemapper.git
```

Enter the downloaded repository:

```bash
cd LocalKeyRemapper
```

Open the Xcode project:

```bash
open LocalKeyRemapper.xcodeproj
```

Unlike a ZIP download, a Git clone preserves the repository information required to:

* inspect commit history;
* switch branches;
* examine tags;
* compare changes;
* create local commits;
* retrieve future updates;
* contribute changes back to the project.

To update an existing clone later:

```bash
cd LocalKeyRemapper
git pull
```

Before pulling updates, make sure that any local modifications have been committed, temporarily stored or otherwise backed up.

---

#### Build and run the source code with Xcode

To compile LocalKeyRemapper yourself, you need:

* a supported Mac;
* a compatible version of macOS;
* a current compatible version of Xcode;
* the LocalKeyRemapper source code.

After opening `LocalKeyRemapper.xcodeproj`:

1. Wait for Xcode to finish loading and indexing the project.
2. Select the `LocalKeyRemapper` scheme.
3. Select **My Mac** as the run destination.
4. Press the Run button or use:

```text
Command + R
```

Xcode will compile the project and launch the resulting application.

When the Xcode-built application first tries to enable remapping, macOS will request Accessibility permission.

Open:

```text
System Settings
→ Privacy & Security
→ Accessibility
```

Enable the LocalKeyRemapper build created by Xcode.

A locally built copy and the packaged release may be treated as separate application builds by macOS. Accessibility permission granted to one build may therefore need to be granted again to another build.

---

#### Why build from source?

Building from source allows you to:

* read the Swift implementation before running it;
* inspect how keyboard events are handled;
* confirm that no networking, analytics or telemetry code is intentionally included;
* examine how profiles and rules are stored;
* modify application behaviour;
* run tests;
* use Xcode’s debugger;
* build a particular commit or release tag;
* independently create the application bundle installed on your Mac.

This is the recommended option for developers, contributors, security reviewers and users who want the greatest possible level of technical control.

---

## Which option should I choose?

For most users:

```text
Download the latest .dmg release.
```

For developers, contributors or users who want maximum practical control:

```text
Clone the repository with Git and open it in Xcode.
```

For users who only want to inspect the files:

```text
Download the source code ZIP.
```

For users who want the highest practical degree of control:

```text
Review the source code, select a specific commit or release tag,
and build the application locally with Xcode.
```

Regardless of the selected method, only obtain LocalKeyRemapper from the official project repository.

---

## What is LocalKeyRemapper?

LocalKeyRemapper is a lightweight native macOS application designed to make keyboard remapping simple, flexible and immediately accessible.

A rule can be as simple as:

```text
V → W
```

When that rule is active, pressing `V` causes macOS to receive `W`.

More advanced configurations can include modifiers, reverse mappings, exceptions, multiple profiles and global activation shortcuts.

LocalKeyRemapper is useful for:

* adapting a keyboard to individual motor or accessibility needs;
* reducing difficult or uncomfortable key movements;
* creating alternative keyboard layouts;
* building dedicated gaming profiles;
* temporarily replacing an unavailable or damaged key;
* creating productivity, development or application-specific layouts;
* supporting one-handed or reduced-movement workflows;
* combining custom remapping rules with macOS Sticky Keys as well.

The application is intentionally focused on one responsibility: **remapping keyboard input safely, locally and efficiently on macOS**.

---

## The story behind LocalKeyRemapper

LocalKeyRemapper started from a very simple requirement: temporarily replace one keyboard key with another on macOS without installing a large, opaque or unnecessarily complex utility.

The project was inspired by the practical keyboard-remapping concept found in **Microsoft PowerToys Keyboard Manager**.

PowerToys is a broad collection of Windows utilities. LocalKeyRemapper takes a deliberately different and more vertical approach: it focuses exclusively on keyboard remapping and develops that single function through deeper rule controls, profiles, macOS modifiers, exceptions, bidirectional mappings and native integration.

macOS already provides one of the most mature and deeply integrated accessibility environments among mainstream operating systems. LocalKeyRemapper was created to complement that foundation by bringing a flexible remapping layer to the platform while respecting the principles commonly associated with the macOS experience:

* accessibility;
* privacy;
* security;
* simplicity;
* responsiveness;
* native integration;
* predictable behaviour.

The objective is not to reproduce PowerToys on macOS.

The objective is to take the useful idea of practical keyboard remapping and redesign it specifically for macOS, with a narrower scope, a more focused interface and stronger control over how the application handles keyboard events.

LocalKeyRemapper is an independent open source project and is not affiliated with, endorsed by or sponsored by Apple or Microsoft.

---

## Main features

### Fast menu bar access

LocalKeyRemapper can be controlled directly from the macOS menu bar.

From the menu bar interface, you can quickly:

* enable or disable remapping;
* see the current remapping state;
* select and activate a saved profile;
* open the main configuration window;
* access the application without keeping its windows open.

The menu bar acts as a lightweight control surface. The actual remapping logic remains separated from the user interface.

---

### Multiple custom profiles

Create multiple independent profiles and give each one a custom name.

For example:

```text
Accessibility
Gaming
Coding
Video Editing
External Keyboard
Left-Handed Layout
```

Each profile can contain its own:

* remapping rules;
* enabled or disabled rules;
* modifier behaviour;
* reverse mappings;
* exceptions;
* activation shortcuts;
* configuration state.

Only the selected saved profile is used by the active remapping engine.

This makes it possible to switch keyboard behaviour without rebuilding the configuration every time.

---

### Custom remapping rules

Each rule defines how one keyboard input should be transformed.

Examples:

```text
V → W
Caps Lock → Escape
Command + Space → Return
Control + J → Down Arrow
```

Rules are configured through the native macOS interface and stored locally.

The rule editor includes validation and conflict detection to help prevent ambiguous or incompatible configurations.

---

### Per-rule activation

Every rule can be enabled or disabled independently.

This allows you to temporarily deactivate a single mapping without deleting it or modifying the rest of the profile.

A profile can therefore contain reusable rules that are only activated when needed.

---

### macOS modifier support

LocalKeyRemapper supports macOS keyboard modifiers, including:

* `⌘` Command;
* `⌥` Option;
* `⌃` Control;
* `⇧` Shift;
* Caps Lock;
* `fn`.

Rules can distinguish between exact modifier combinations and configurations that preserve additional modifiers.

This allows both precise mappings and more flexible behaviours.

---

### Reverse and bidirectional remapping

Reverse mapping can be enabled for individual rules.

For example, a standard rule:

```text
V → W
```

can become bidirectional:

```text
V ⇄ W
```

With reverse mapping enabled:

* pressing `V` produces `W`;
* pressing `W` produces `V`.

Reverse behaviour remains part of the rule configuration and can be controlled without creating and maintaining a second manual rule.

---

### Per-rule exceptions

Rules can contain their own exceptions.

An exception defines a specific key or modifier context in which the main rule should not behave normally and can instead follow a separately configured action.

This is useful when a remapping should apply in most situations but selected combinations must remain available or behave differently.

Exceptions can be managed independently and participate in the application’s validation and conflict-detection system.

---

### Sticky Keys compatibility

LocalKeyRemapper is designed to work with the macOS **Sticky Keys** accessibility feature.

Sticky Keys allows modifier keys to remain active without requiring them to be physically held down. LocalKeyRemapper accounts for modifier state when evaluating remapping rules, helping custom layouts remain usable within accessibility-oriented keyboard workflows.

---

### Global and profile-specific shortcuts

Keyboard shortcuts can be configured to control LocalKeyRemapper without opening the application.

Supported actions include:

* toggle remapping;
* enable remapping;
* disable remapping;

Shortcuts are validated against configured rules and other application shortcuts to reduce conflicts and unintended behaviour.

---

### Rule management tools

The rules interface is designed to remain usable with both small and larger configurations.

Available management tools include:

* search;
* sorting;
* filtering;
* conflict indicators;
* validation messages;
* rule activation controls;
* undo and redo;
* safe local saving.

Configuration editing and live remapping are intentionally separated so that interface operations do not run inside the keyboard event-processing path.

---

## Accessibility first

Keyboard remapping is not only a productivity feature.

For some users, changing the position or behaviour of a key can reduce physical strain, avoid painful movements or make a keyboard usable in a way that better matches their motor abilities.

LocalKeyRemapper is designed around the idea that users should be able to adapt their keyboard to themselves rather than being forced to adapt themselves to a fixed layout.

Possible accessibility uses include:

* moving frequently used keys closer together;
* avoiding difficult finger combinations;
* replacing keys that are hard to reach;
* supporting one-handed (or foot) interaction;
* reducing repetitive movement;
* creating layouts for specific assistive workflows;
* combining remapping with Sticky Keys;
* creating separate profiles for different physical setups.

Accessibility is not treated as an optional mode or an additional layer. It is one of the project’s central design principles.

At the same time, LocalKeyRemapper remains useful for gaming, software development, creative applications and general productivity. Accessibility and practicality are not competing goals.

---

## Privacy first

A keyboard-remapping application necessarily interacts with keyboard events. That makes privacy a fundamental architectural requirement rather than a marketing feature.

LocalKeyRemapper is designed to process only the information required to evaluate the active remapping rules.

The application does **not**:

* record what you type;
* create a keystroke history;
* save keyboard-event logs;
* store the time at which keys were pressed;
* collect usage statistics;
* send crash reports to cloud services;
* use analytics or telemetry;
* require an account;
* connect to an external server;
* upload profiles or configurations;
* include advertising or tracking systems.

LocalKeyRemapper has no functional reason to connect to the Internet.

The configuration stored locally may include:

* profile names;
* configured remapping rules;
* modifier settings;
* exceptions;
* shortcuts;
* interface preferences.

It does not include the content typed while the application is running.

---

## Security first

LocalKeyRemapper requires macOS Accessibility permission because modifying keyboard events is a protected system capability.

This permission is powerful and must be treated accordingly.

The application uses it only to implement the remapping behaviour requested by the user.

LocalKeyRemapper does not require:

* root access;
* a privileged helper;
* a system-wide background daemon;
* cloud authentication;
* a remote configuration service;
* browser extensions;
* external scripts;
* third-party analytics frameworks.

The project intentionally keeps its scope narrow. A smaller and more understandable codebase reduces unnecessary complexity and makes the application easier to inspect, test and audit.

**The source code is available so that its behaviour can be reviewed directly.**

---

## Performance without sacrificing control

Keyboard events must be processed quickly. Even a small delay can be noticeable while typing or gaming.

LocalKeyRemapper is built natively for macOS using Swift, AppKit and system event APIs.

The remapping path is designed to remain minimal:

```text
Keyboard event
      ↓
Read key code and modifiers
      ↓
Evaluate the active in-memory rules
      ↓
Return the original or modified event
```

The event callback does not perform:

* network requests;
* disk writes;
* profile loading;
* interface updates;
* analytics;
* configuration decoding;
* unnecessary asynchronous work.

Rules are prepared before active remapping begins and are evaluated in memory.

Absolute zero latency is not physically realistic for any software transformation. The objective is instead to keep processing latency practically imperceptible while maintaining safe and predictable behaviour.

Privacy, security and accessibility are not used as excuses for poor performance, and performance is not obtained by weakening privacy or security.

---

## How LocalKeyRemapper works

LocalKeyRemapper uses native macOS event-handling APIs to receive relevant keyboard events while remapping is enabled.

For a rule such as:

```text
V → W
```

the simplified event flow is:

```text
1. macOS produces a key-down event for V.
2. LocalKeyRemapper reads the virtual key code and active modifiers.
3. The active profile is evaluated.
4. The matching rule is found.
5. The event key code is changed from V to W.
6. The modified event is returned to macOS.
7. The active application receives W.
8. The corresponding key-up event is transformed consistently.
```

LocalKeyRemapper operates on keyboard event data such as virtual key codes and modifiers. It does not need to reconstruct, understand or store the words being typed.

When remapping is disabled, configured transformations are not applied.

The menu bar and configuration windows do not process keyboard events directly. They communicate with a dedicated remapping controller, keeping the user interface separated from the system-level event path.

---

## Architecture

LocalKeyRemapper uses a modular architecture with separated responsibilities.

```text
Application and menu bar
          ↓
Remapping controller
          ↓
 ┌────────┼───────────┐
 ↓        ↓           ↓
Profiles  Rule engine Event tap
store     and rules   management
```

The main areas are:

* **Application coordination** — creates and connects the application components;
* **Menu bar and windows** — provide controls and configuration interfaces;
* **Remapping controller** — manages the real enabled or disabled state;
* **Event tap management** — communicates with the macOS keyboard event system;
* **Remapping engine** — evaluates active rules, modifiers, reverse mappings and exceptions;
* **Profile and configuration storage** — saves only local user-defined settings;
* **Validation system** — detects rule and shortcut conflicts before activation.

This separation keeps system-level code away from interface code and makes the project easier to test, maintain and extend.

---

## Example configurations

### Replace a difficult-to-reach key

```text
Right Command + Caps Lock → Return
```

### Create a gaming layout

```text
V → W
C → A
B → D
Space → S
```

### Exchange two keys

```text
V ⇄ W
```

### Create separate environments

```text
Profile: Accessibility
Profile: Gaming
Profile: Coding
Profile: External Keyboard
```

The same physical keyboard can therefore behave differently depending on the active saved profile.

---

## Frequently asked questions

### Does LocalKeyRemapper record my keystrokes?

No.

LocalKeyRemapper evaluates keyboard events only to determine whether an active remapping rule applies. It does not create a keystroke history, save typed content or generate input logs.

---

### Does LocalKeyRemapper connect to the Internet?

No.

The application does not require Internet access, online accounts, analytics, telemetry, advertisements or cloud services.

---

### Is LocalKeyRemapper a keylogger?

No.

A keylogger records keyboard input for later inspection or transmission. LocalKeyRemapper performs an immediate transformation based on user-configured rules and returns the event to macOS without storing the typed input.

---

### Why does it require Accessibility permission?

macOS protects applications from silently controlling or modifying system input.

Accessibility permission allows LocalKeyRemapper to perform the keyboard transformations explicitly configured by the user. The permission does not remove the project’s privacy obligations, which is why the application avoids logging, analytics, networking and unnecessary data collection.

---

### Does it work with Sticky Keys?

Yes! LocalKeyRemapper is designed to remain compatible with the modifier states produced by macOS Sticky Keys.

---

### Can I create gaming or productivity profiles?

Yes.

Profiles can contain independent rules, modifier behaviours, reverse mappings, exceptions and activation settings.

---

### Can individual rules be temporarily disabled?

Yes.

Each rule can be activated or deactivated without removing it from the profile.

---

### Can two keys be exchanged?

Yes.

Enable reverse mapping on a rule to create a bidirectional transformation such as:

```text
V ⇄ W
```

---

### Is this PowerToys for Mac?

LocalKeyRemapper was inspired by the practical keyboard-remapping concept available in Microsoft PowerToys Keyboard Manager.

However, it is not a PowerToys port or clone. It is a focused native macOS application dedicated exclusively to keyboard remapping, accessibility, profiles, modifiers, reverse mappings, exceptions.

 LocalKeyRemapper is focused on privacy, security, real accessibility and low-latency operation.

---

## Project principles

Every future feature should be evaluated against the same requirements:

1. Does it improve keyboard remapping or accessibility?
2. Can it remain completely local?
3. Does it preserve user privacy?
4. Does it avoid unnecessary permissions?
5. Does it maintain predictable behaviour?
6. Does it preserve practically imperceptible latency?
7. Can the implementation remain understandable and auditable?
8. Does it avoid unnecessary background resource usage?
9. Can it be added without turning the application into an unrelated utility suite?

Features that conflict with these principles should not be added simply to increase the number of available options.

---

## Contributing

Contributions, testing and accessibility feedback are welcome.

When proposing a change, please describe:

* the problem being solved;
* the accessibility or usability benefit;
* any required macOS permissions;
* the expected performance impact;
* the privacy and security implications;
* how the behaviour can be tested;
* whether the change affects existing profiles or rules.

Changes that introduce networking, telemetry, cloud dependencies, keyboard logging or unnecessary privileged components are outside the intended scope of the project.

---

## License

LocalKeyRemapper is released under the **MIT License**.

Copyright © 2026 Alessandro Giuriati.

---

## Independence notice

LocalKeyRemapper is an independent open-source project.

Apple, macOS, Mac and related names are trademarks of Apple Inc.

Microsoft, Windows, PowerToys and related names are trademarks of Microsoft Corporation.

LocalKeyRemapper is not affiliated with, endorsed by or sponsored by Apple or Microsoft.
