# CodeAurora mirror manifest

This repository provides a cron-updated manifest for mirroring all of CodeAurora Android-related repositories.

## How to use

```
mkdir -p /mirror/caf
cd /mirror/caf
repo init -u https://github.com/arter97/caf_mirror_manifest --mirror
repo sync -j16
```

It is recommended that you have an AOSP mirror already:
```
mkdir -p /mirror/aosp
cd /mirror/aosp
repo init -u https://android.googlesource.com/mirror/manifest --mirror
repo sync -j16

mkdir -p /mirror/caf
cd /mirror/caf
repo init -u https://github.com/arter97/caf_mirror_manifest --mirror --reference=/mirror/aosp
repo sync -j16
```

## Storage

As of time of writing, the AOSP mirror takes 746 GiB and CAF mirror (when AOSP mirror is referenced) takes 20 GiB of storage.

We currently store AOSP mirror's `device/` (kernel binary Git repositories are huge) and
`platform/external/chromium-webview.git/` on a HDD with bind mounts to reduce SSD storage usage.
Those directories use 310 GiB of space with almost no benefit to use fast storage.

## Custom ROMs

Note that while unmodified, upstream repositories from CAF or AOSP will use the mirror,
custom ROM's repositories hosted on GitHub will not automatically benefit from the mirror.

For example, when you `repo init` Paranoid Android with `--mirror` to this mirror,
`AOSPA/android_frameworks_base.git`, `AOSPA/android_packages_apps_Settings.git` and the likes will not
automatically use the mirrored objects.

This is due to the `name` format difference in the XML.

Completely working around this is not worth the effort, but for `android_frameworks_base` and
`android_packages_apps_Settings` (2 repositories that take the most space in custom ROM's repositories),
it may be worth it to forcefully use the mirrored objects so that the initial clone is shorter.

To do this, perform a manual `repo sync frameworks/base` after `repo init` and ^C (Ctrl-C) after Git starts downloading.
Do the same with `packages/apps/Settings`.

With this, the initial Git structure is ready.
After that:
```
echo /mirror/caf/platform/frameworks/base.git/objects > .repo/project-objects/AOSPA/android_frameworks_base.git/objects/info/alternates
rm -f .repo/project-objects/AOSPA/android_frameworks_base.git/objects/tmp_pack*

echo /mirror/caf/platform/packages/apps/Settings.git/objects > .repo/project-objects/AOSPA/android_packages_apps_Settings.git/objects/info/alternates
rm -f .repo/project-objects/AOSPA/android_packages_apps_Settings.git/objects/tmp_pack*
```
and perform a `repo sync -j16` again.

This time, Git will reference the mirrored objects.

## How it works

If you want to run this yourself...

#### pull.sh

Creates legacy, system and vendor directory for CAF Git clones and pulls updates from them.
These directories are added to `.gitignore`.

#### manifest.sh

Reads all LA.UM XML files from `*/*.xml` and creates final `default.xml`.

#### blacklist.txt

Few repositories in older XML files are broken.
`blacklist.txt` includes several broken repositories so that the created manifest doesn't include those.

As of time of writing, the following repositories are broken and excluded via `blacklist.txt`:
```
platform/tools/vendor/google_prebuilts/arc
platform/vendor/google_easel
platform/vendor/google_paintbox
quic/la/toolchain/binutils
quic/le/live555
quic/le/platform/vendor/qcom-opensource/qmmf-sdk
quic/le/platform/vendor/qcom-opensource/qmmf-webserver
```

#### cron.sh

For cronjob registration. This is executed every 8 AM KST.
