{
  pkgs,
  inputs,
  owner,
  lib,
  ...
}:
let
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

in
{
  home.packages = [ pkgs-unstable.code-cursor ];

  # Install settings for Cursor
  # TODO: Consider making these settings your own preferences
  home.activation.installCursorSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v cursor &>/dev/null; then
      cat >/home/${owner.name}/.config/Cursor/User/settings.json} <<EOL
{
    "window.autoDetectColorScheme": true,
    "workbench.preferredLightColorTheme": "Default Dark+",
    "workbench.externalBrowser": "chromium"
}
EOL

      cat >/home/${owner.name}/.config/Cursor/User/keybindings.json <<EOL
[
  {
    "command": "workbench.action.terminal.toggleTerminal",
    "key": "ctrl+e"
  },
  {
    "command": "git.unstageSelectedRanges",
    "key": "ctrl+k ctrl+u",
    "when": "editorTextFocus && resourceScheme == 'git'"
  },
  {
    "key": "ctrl+d",
    "command": "workbench.action.toggleAgentsFromKeyboard",
    "when": "!isAuxiliaryWindowFocusedContext && !isGlass"
  },
  {
    "key": "ctrl+alt+j",
    "command": "-workbench.action.toggleAgentsFromKeyboard",
    "when": "!isAuxiliaryWindowFocusedContext && !isGlass"
  }
]
EOL

      cursor --install-extension eamodio.gitlens 2>/dev/null || true

    fi

  '';

  # Cursor's icon ships in share/pixmaps/ which fuzzel doesn't search.
  # Surfacing it under the hicolor theme so .desktop's Icon=cursor
  # resolves in launchers.
  xdg.dataFile."icons/hicolor/512x512/apps/cursor.png".source =
    "${pkgs-unstable.code-cursor}/share/pixmaps/cursor.png";
}
