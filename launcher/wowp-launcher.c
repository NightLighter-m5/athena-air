// World of Warplanes app: tiny launcher that sits in front of Sikarugir.
// Installed as  WorldOfWarplanes.app/Contents/MacOS/launcher  (the app's CFBundleExecutable).
// It runs Contents/Resources/Athena/prelaunch.sh (menu: Play / Game Center / Settings,
// engine switching, leftovers, resolution, Low Power) and then becomes the real
// Sikarugir launcher, unless prelaunch.sh exits with 10 (nothing to start).
// If anything here fails, it still starts Sikarugir, so the app always opens.
//
// Build:  clang -O2 -arch arm64 -arch x86_64 -mmacosx-version-min=14.0 -o launcher wowp-launcher.c
// Undo:   cd WorldOfWarplanes.app/Contents/MacOS && rm launcher && ln -s Sikarugir launcher
#include <libgen.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

int main(int argc, char *argv[]) {
    char raw[PATH_MAX], exe[PATH_MAX], dir[PATH_MAX], script[PATH_MAX], real[PATH_MAX];
    uint32_t size = sizeof(raw);
    if (_NSGetExecutablePath(raw, &size) != 0 || realpath(raw, exe) == NULL) return 1;
    strlcpy(dir, dirname(exe), sizeof(dir));
    snprintf(script, sizeof(script), "%s/../Resources/Athena/prelaunch.sh", dir);
    snprintf(real, sizeof(real), "%s/Sikarugir", dir);

    // Sikarugir's own maintenance modes (installers etc.) are passed straight through.
    int plain = 1;
    for (int i = 1; i < argc; i++)
        if (strncmp(argv[i], "WSS-", 4) == 0) plain = 0;

    if (plain && access(script, R_OK) == 0) {
        char *args[] = {"/bin/bash", script, NULL};
        pid_t pid;
        if (posix_spawn(&pid, "/bin/bash", NULL, NULL, args, environ) == 0) {
            int status;
            waitpid(pid, &status, 0);
            // 10 = the menu was closed, a setting was opened, or the game is already running
            if (WIFEXITED(status) && WEXITSTATUS(status) == 10) return 0;
        }
    }
    argv[0] = real;
    execv(real, argv);
    perror("execv Sikarugir");
    return 1;
}
