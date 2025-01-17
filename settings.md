# Settings

## Notification
**\[ \] Notify if a major release is available**  
**\[ \] Notify if a point release is available**  
**Check every \[#\] \[units\]**  
Starts a background process that periodically checks for new kernels and sends a desktop notification if a kernel is available that you don't have installed yet.  
The monitor is installed in your desktop autostart folder such that it is started in the background any time you log in.  
It is removed by unselecting both checkboxes.  

## Filters
**\[ \] Hide unstable and RC releases**  
Excludes less stable more bleeding edge -rc kernels from the list.

**\[ \] Hide failed or incomplete builds**  
Excludes less stable more bleeding edge -rc kernels from the list.

**Show \[ \] previous major versions**  
Defines a threshold value for the oldest major version to include in the display, as an offset from the whatever the current latest version is.  

The threshold is whichever is lower:  
 - the oldest mainline kernel you have installed
 - the highest mainline version available minus N

The special value "-1" is also allowed, and means to show all possible kernel versions. With this setting the initial cache update or Reload takes a long time, but it's usable after that.

Any installed non-mainline kernels are ignored for this.  
This allows to have a prior-generation distribution kernel installed without causing the list to include the entire prior generation of mainline kernels for no reason.  

Generally, you want this setting to just be 0.  

## Network
**Internet connection timeout in \[##\] seconds**  
**Max concurrent downloads \[#\]**  

**\[ \] Verify Downloads with the CHECKSUMS files**  
When downloading .deb packages, first download the CHECKSUMS file and extract the sha-256 hashes from it, and use them to verify the .deb file downloads.

**\[ \] Keep Downloads**  
Don't delete the .deb files after installing them. This allows to uninstall & reinstall kernels without having to re-download them.  
The cache is still kept trimmed even with this option enabled. The cache for any kernels that are older than the "Show N previous major versions" setting are still deleted as normal, so the cache grows but does not grow forever. And the datestamp comparison that detects when already-cached kernels have been changed on the mainline-ppa site, still deletes any out-of-date cached kernels as normal, so the setting does not result in retaining out-of-date kernel packages either. The "Reload" button still deletes everything too.

**Proxy  
\[_________________________________________________\]**  
proxy support via aria2c's [all-proxy](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-all-proxy) setting

**mainline-ppa url  
\[https://kernel.ubuntu.com/mainline/  \]**  

## External Commands  
auth command  
**\[pkexec_________________________________________\]**  
sudo-equivalent command used to run `dpkg` as root.

There are several built-in "sudo-alike" commands to select from, or you can edit your own custom command.

The syntax is direct/literal, with one optional exception.  
dpkg commands that need root permissions (install/uninstall) are simply appended after whatever is entered here.  
The default is `pkexec`, and so the resulting dpkg commands will be `pkexec dpkg -i file.deb file.deb ...`

If you need the dpkg command to be included/embedded within a string rather than appended to the end, you can place a single `%s` in the string, and it will be replaced with the dpkg command. Any other %'s are treated as literal % characters, only %s is recognized, and only a single one, the first occurance if more than one.  
One of the built-in default options shows an example: `su -c "%s"` it needs the %s feature because it needs the closing quote after the end of the dpkg command.

To write a custom entry, just click on the field and start writing. You can start with the blank entry or any of the built-in ones. Your edited version is saved as a new custom entry. The built-in defaults are not changed, so it's safe to pick one to start from and edit it. It's also possible to leave the field blank, in which case no sudo-like command will be used. You might use this option if you run mainline itself as root, though that is not advised.

If you are operating entirely from the command line, and so can not access the Settings gui, you can manually edit auth_cmd in ~/.config/mainline/config.json

terminal window  
**\[\[internal-vte\]_________________________________\]**  
xterm-equivalent command used to run `BRANDING_SHORTNAME --install/--uninstall` in.

You can specify almost any terminal program, but one limitation is the program must stay in the foreground and block while the command is running.  
Most do this by default, but some need special commandline flags, ie gnome -> `--wait`, kde -> `--no-fork`, xfce4 -> `--disable-server`

After selecting a command (other than the default \[internal-vte\])), you can edit it to customize the terminal's appearance.
