# CLAUDE.md

FishyWashy is a World of Warcraft Classic fishing addon, published on CurseForge and GitHub.

## Releasing

1. Bump `## Version` in `FishyWashy.toc`: a new feature bumps the minor version, a fix the patch version.
2. Add the version's notes at the top of `CHANGELOG.md`, and replace `RELEASE_NOTES.md` with only that version's notes. CurseForge shows `RELEASE_NOTES.md` as the file's changelog.
3. Commit as `Release X.Y.Z: <what's new>`, and tag the commit `vX.Y.Z` (a lightweight tag).
4. Push the branch and the tag in one push:

   ```sh
   git push --atomic origin main vX.Y.Z
   ```

   Never push the release commit on its own first. See CurseForge packaging below.
5. Create the GitHub release, named `FishyWashy X.Y.Z`, with the release notes as its body and the addon zip attached:

   ```sh
   git archive --format=zip --prefix=FishyWashy/ -o FishyWashy-X.Y.Z.zip vX.Y.Z -- . ':!.gitattributes' ':!.gitignore' ':!.pkgmeta' ':!*.md' ':!docs'
   gh release create vX.Y.Z FishyWashy-X.Y.Z.zip --verify-tag --title "FishyWashy X.Y.Z" --notes-file RELEASE_NOTES.md
   ```

   The zip holds a `FishyWashy/` folder with only the addon's files, the same files `.pkgmeta` packages.

## CurseForge packaging

CurseForge packages every push to `main` as an alpha, such as `v1.1.0-2-g113e820-alpha`, and every `vX.Y.Z` tag as a release. `.pkgmeta` leaves the docs and Markdown files out of the package. CurseForge rejects a file whose content duplicates one already uploaded, which means:

- If the release commit reaches `main` before its tag, it's packaged as an alpha first, and the release built from the tag is then rejected as a duplicate. Release-channel users never get the update. This happened with 1.2.0.
- Commits that only change docs or Markdown files make alphas identical to the last build, which are rejected as duplicates. That's harmless.

If a release is rejected as a duplicate of an alpha: edit the approved alpha in CurseForge to be a Release named `vX.Y.Z` with the release notes, ask CurseForge support to approve the release, or release the next patch version.

Add new files that aren't part of the addon, like this one, to the `ignore` list in `.pkgmeta`.
