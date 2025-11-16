# Hex Release Checklist for Bloomy v0.1.0

## ✅ Pre-Release Checklist

### Package Files
- [x] LICENSE (Apache 2.0)
- [x] CHANGELOG.md
- [x] README.md (comprehensive with examples)
- [x] mix.exs (complete with metadata)
- [x] .formatter.exs
- [x] All library files in lib/

### Package Metadata (mix.exs)
- [x] Version: 0.1.0
- [x] Description: High-performance Bloom Filter library
- [x] License: Apache-2.0
- [x] Links: GitHub, Changelog
- [x] Dependencies properly marked:
  - [x] nx (required)
  - [x] exla (optional)
  - [x] scholar (optional)
  - [x] ex_doc (dev only)
  - [x] benchee (dev only)

### Code Quality
- [x] All tests passing (9/9)
- [x] Zero compiler warnings
- [x] Code compiles cleanly
- [x] Documentation complete
- [x] Examples provided

### Git Repository
- [x] All changes committed
- [x] Clean working directory
- [x] Meaningful commit history
- [x] Test files moved to examples/

### Package Build
- [x] Package builds successfully: `mix hex.build`
- [x] No errors or warnings in build
- [x] All required files included

## 📋 Before Publishing

### 1. Update GitHub Repository URL
Edit `mix.exs` line 5:
```elixir
@source_url "https://github.com/YOUR_USERNAME/bloomy"
```
Replace `YOUR_USERNAME` with actual GitHub username.

### 2. Update Maintainer Information
Edit `mix.exs` line 54:
```elixir
maintainers: ["Your Name"]
```
Replace with actual name/email.

### 3. Create GitHub Repository
```bash
# On GitHub, create a new repository named 'bloomy'
git remote add origin https://github.com/YOUR_USERNAME/bloomy.git
git push -u origin master
```

### 4. Create Git Tag
```bash
git tag -a v0.1.0 -m "Release version 0.1.0"
git push origin v0.1.0
```

## 🚀 Publishing to Hex

### Step 1: Verify Package
```bash
mix hex.build --unpack
```
Review the output to ensure all files are included.

### Step 2: Publish (Dry Run)
```bash
mix hex.publish --dry-run
```
This shows what would be published without actually publishing.

### Step 3: Publish
```bash
mix hex.publish
```

You will be prompted to:
1. Review package details
2. Confirm publication
3. Enter your Hex.pm credentials

### Step 4: Verify
After publishing:
1. Visit https://hex.pm/packages/bloomy
2. Check documentation at https://hexdocs.pm/bloomy
3. Test installation: `mix hex.info bloomy`

## 📚 Post-Release

### Update Documentation
```bash
mix docs
# Documentation will be generated in doc/
# Hex automatically hosts docs at hexdocs.pm
```

### Announce Release
- Create GitHub Release with changelog
- Update project README if needed
- Share on Elixir forums/communities (optional)

## 🔧 Future Releases

For subsequent releases:
1. Update version in `mix.exs`
2. Update `CHANGELOG.md` with changes
3. Run full test suite
4. Commit changes
5. Create git tag
6. Run `mix hex.publish`

## ⚠️ Important Notes

- **First Publication**: Hex will reserve the package name upon first publish
- **Version Numbers**: Follow semantic versioning (MAJOR.MINOR.PATCH)
- **Breaking Changes**: Bump MAJOR version
- **New Features**: Bump MINOR version
- **Bug Fixes**: Bump PATCH version

## 🎯 Current Status

✅ **READY FOR PUBLICATION**

All requirements met:
- Code quality: ✅
- Tests passing: ✅ (9/9)
- Documentation: ✅
- Package metadata: ✅
- License: ✅ (Apache 2.0)
- Changelog: ✅

**Next Steps:**
1. Update GitHub URL in mix.exs
2. Update maintainer name
3. Create GitHub repository
4. Push code to GitHub
5. Run `mix hex.publish`

---

## Example Installation (After Publishing)

Users will install with:
```elixir
def deps do
  [
    {:bloomy, "~> 0.1.0"},
    {:nx, "~> 0.10.0"},
    {:exla, "~> 0.10.0"}  # Optional but recommended
  ]
end
```

---

*Prepared: 2025-11-16*
*Version: 0.1.0*
*Status: Ready for Publication*
