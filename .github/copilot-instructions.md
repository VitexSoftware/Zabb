<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->
- [ ] Verify that the copilot-instructions.md file in the .github directory is created.

- [ ] Clarify Project Requirements
	<!-- Ask for project type, language, and frameworks if not specified. Skip if already provided. -->

- [ ] Scaffold the Project
	<!--
	Ensure that the previous step has been marked as completed.
	Call project setup tool with projectType parameter.
	Run scaffolding command to create project files and folders.
	Use '.' as the working directory.
	If no appropriate projectType is available, search documentation using available tools.
	Otherwise, create the project structure manually using available file creation tools.
	-->

- [ ] Customize the Project
	<!--
	Verify that all previous steps have been completed successfully and you have marked the step as completed.
	Develop a plan to modify codebase according to user requirements.
	Apply modifications using appropriate tools and user-provided references.
	Skip this step for "Hello World" projects.
	-->

- [ ] Install Required Extensions
	<!-- ONLY install extensions provided mentioned in the get_project_setup_info. Skip this step otherwise and mark as completed. -->

- [ ] Compile the Project
	<!--
	Verify that all previous steps have been completed.
	Install any missing dependencies.
	Run diagnostics and resolve any issues.
	Check for markdown files in project folder for relevant instructions on how to do this.
	-->

- [ ] Create and Run Task
	<!--
	Verify that all previous steps have been completed.
	Check https://code.visualstudio.com/docs/debugtest/tasks to determine if the project needs a task. If so, use the create_and_run_task to create and launch a task based on package.json, README.md, and project structure.
	Skip this step otherwise.
	 -->

- [ ] Launch the Project
	<!--
	Verify that all previous steps have been completed.
	Prompt user for debug mode, launch only if confirmed.
	 -->

- [ ] Ensure Documentation is Complete
	<!--
	Verify that all previous steps have been completed.
	Verify that README.md and the copilot-instructions.md file in the .github directory exists and contains current project information.
	Clean up the copilot-instructions.md file in the .github directory by removing all HTML comments.
	 -->

<!--
## Execution Guidelines
PROGRESS TRACKING:
- If any tools are available to manage the above todo list, use it to track progress through this checklist.
- After completing each step, mark it complete and add a summary.
- Read current todo list status before starting each new step.

COMMUNICATION RULES:
- Avoid verbose explanations or printing full command outputs.
- If a step is skipped, state that briefly (e.g. "No extensions needed").
- Do not explain project structure unless asked.
- Keep explanations concise and focused.

DEVELOPMENT RULES:
- Use '.' as the working directory unless user specifies otherwise.
- Avoid adding media or external links unless explicitly requested.
- Use placeholders only with a note that they should be replaced.
- Use VS Code API tool only for VS Code extension projects.
- Once the project is created, it is already opened in Visual Studio Code—do not suggest commands to open this project in Visual Studio again.
- If the project setup information has additional rules, follow them strictly.

FOLDER CREATION RULES:
- Always use the current directory as the project root.
- If you are running any terminal commands, use the '.' argument to ensure that the current working directory is used ALWAYS.
- Do not create a new folder unless the user explicitly requests it besides a .vscode folder for a tasks.json file.
- If any of the scaffolding commands mention that the folder name is not correct, let the user know to create a new folder with the correct name and then reopen it again in vscode.

EXTENSION INSTALLATION RULES:
- Only install extension specified by the get_project_setup_info tool. DO NOT INSTALL any other extensions.

PROJECT CONTENT RULES:
- If the user has not specified project details, assume they want a "Hello World" project as a starting point.
- Avoid adding links of any type (URLs, files, folders, etc.) or integrations that are not explicitly required.
- Avoid generating images, videos, or any other media files unless explicitly requested.
- If you need to use any media assets as placeholders, let the user know that these are placeholders and should be replaced with the actual assets later.
- Ensure all generated components serve a clear purpose within the user's requested workflow.
- If a feature is assumed but not confirmed, prompt the user for clarification before including it.
- If you are working on a VS Code extension, use the VS Code API tool with a query to find relevant VS Code API references and samples related to that query.

TASK COMPLETION RULES:
- Your task is complete when:
  - Project is successfully scaffolded and compiled without errors
  - copilot-instructions.md file in the .github directory exists in the project
  - README.md file exists and is up to date
  - User is provided with clear instructions to debug/launch the project

Before starting a new task in the above plan, update progress in the plan.
-->
- Work through each checklist item systematically.
- Keep communication concise and focused.
- Follow development best practices.

## F-Droid Release Process

Zabb is submitted to F-Droid. Tracking: RFP issue
[fdroid/rfp#3445](https://gitlab.com/fdroid/rfp/-/issues/3445), build recipe MR
[fdroid/fdroiddata!37096](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/37096).
The metadata lives in a fork at `gitlab.com/vitexus/fdroiddata`
(branch `com.vitexsoftware.zabb`, file `metadata/com.vitexsoftware.zabb.yml`),
cloned locally at `~/Projects/F-Droid/fdroiddata`.

### What every release needs

1. **Tagged release**: `pubspec.yaml`'s `version:` field uses a `+N` build
   number that increments every release (e.g. `0.6.7+7`). F-Droid derives its
   `versionCode` from this via `UpdateCheckData` regex — don't reuse a build
   number. Tag as `vX.Y.Z` matching the version name.
2. **`pubspec.lock` must be in sync with `pubspec.yaml`**. F-Droid's build
   recipe runs `flutter pub get --enforce-lockfile`, which fails hard on any
   drift (unlike a plain `pub get`, which would silently just update the
   lock). Regenerate and commit `pubspec.lock` before tagging if `pubspec.yaml`
   dependency constraints changed.
3. **Flutter version pin**: the build recipe extracts the Flutter version from
   `.github/workflows/build.yml`'s `flutter-version` field at build time —
   keep that current.
4. **Real signing key**: releases are signed with a dedicated 4096-bit RSA key
   (not the shared Android debug key). The keystore lives outside this repo at
   `~/.keystores/zabb-release.jks`, backed up (password + file) in Vaultwarden
   under "Zabb Android Release Signing Key". It's wired in via a git-ignored
   `android/key.properties` (see `android/app/build.gradle` — falls back to
   debug signing when that file is absent, which is what happens on F-Droid's
   own build server; they re-sign with their own key when publishing anyway).

### ABI-split APKs

F-Droid builds three separate, smaller APKs per release instead of one
universal one. `android/app/build.gradle` computes a distinct `versionCode`
per ABI: `baseVersionCode * 10 + abiDigit`, where
`armeabi-v7a=1, arm64-v8a=2, x86_64=3` (see the `abiCodes` map). The F-Droid
metadata has one `Builds:` entry per ABI/versionCode, each running
`flutter build apk --release --split-per-abi --target-platform="android-*"`.

### Reproducible builds

The metadata sets `Binaries:` and `AllowedAPKSigningKeys:` so F-Droid verifies
its own build matches a reference APK you publish. This only works if the
reference APK is byte-identical to F-Droid's build — Flutter's Dart AOT
compiler embeds the absolute source checkout path into the compiled native
library (`lib/*/libapp.so`), so **the reference APK must be built from the
exact same path F-Droid's build server uses**: `/home/vagrant/build/com.vitexsoftware.zabb`.

To build a matching reference APK locally:

```bash
sudo mkdir -p /home/vagrant/build && sudo chown -R $(whoami) /home/vagrant   # one-time
rm -rf /home/vagrant/build/com.vitexsoftware.zabb
mkdir -p /home/vagrant/build/com.vitexsoftware.zabb
git archive vX.Y.Z | tar -x -C /home/vagrant/build/com.vitexsoftware.zabb
cp android/key.properties /home/vagrant/build/com.vitexsoftware.zabb/android/key.properties
chmod 600 /home/vagrant/build/com.vitexsoftware.zabb/android/key.properties
chmod -R go-rwx /home/vagrant/build/com.vitexsoftware.zabb   # key.properties has real credentials
cd /home/vagrant/build/com.vitexsoftware.zabb
flutter build apk --release --split-per-abi --target-platform="android-arm"    # armeabi-v7a
flutter build apk --release --split-per-abi --target-platform="android-arm64" # arm64-v8a
flutter build apk --release --split-per-abi --target-platform="android-x64"   # x86_64
```

Then verify each APK is signed with the real key (not debug) before
publishing: `apksigner verify --print-certs <apk>`.

The F-Droid build recipe itself does **not** need a matching move/`cd` dance —
their infrastructure (and the MR's GitLab CI runner) already checks out
natively at that exact path.

### GitHub release naming

Upload each ABI's APK as `zabb-<versionCode>.apk` (e.g. `zabb-71.apk` for
armeabi-v7a versionCode 71) on the GitHub release for that tag. This matches
the metadata's `Binaries:` template:
`https://github.com/VitexSoftware/Zabb/releases/download/v%v/zabb-%c.apk`.

### Release checklist

1. Bump `pubspec.yaml` version (`+N` build number), regenerate `pubspec.lock`
   if needed, add F-Droid changelog files at
   `metadata/en-US/changelogs/<versionCode>.txt` for each of the 3 ABI codes.
2. Run tests (`flutter test`), commit, push to `main`, tag `vX.Y.Z`, push tag.
3. Build the 3 reference APKs from `/home/vagrant/build/com.vitexsoftware.zabb`
   as above; verify signatures.
4. Publish a GitHub release for the tag with the 3 APKs named
   `zabb-<versionCode>.apk`.
5. In `~/Projects/F-Droid/fdroiddata`, add/update the `Builds:` entries (3 per
   release, one per ABI) and bump `CurrentVersion`/`CurrentVersionCode` in
   `metadata/com.vitexsoftware.zabb.yml`. Run `fdroid rewritemeta
   com.vitexsoftware.zabb` and `fdroid lint com.vitexsoftware.zabb`.
6. Verify locally: `fdroid build --force --test com.vitexsoftware.zabb:<versionCode>`
   for each ABI — should report "compared built binary to supplied reference
   binary successfully".
7. Commit, push to the `com.vitexsoftware.zabb` branch of the fork
   (`~/Projects/F-Droid/fdroiddata`), which updates MR !37096 and triggers its
   CI pipeline. Confirm all jobs pass (`fdroid build`, `check apk`, lint,
   schema validation, etc.) before considering the release done.
