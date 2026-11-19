#!/usr/bin/env python3
"""Generates a clean native macOS TikTokDesktop.xcodeproj for Xcode & xcodebuild."""

import hashlib
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC_ROOT = ROOT / "TikTokDesktop"
PROJ_DIR = ROOT / "TikTokDesktop.xcodeproj"
SCHEME_DIR = PROJ_DIR / "xcshareddata" / "xcschemes"


def uid(seed: str) -> str:
    return hashlib.sha1(seed.encode("utf-8")).hexdigest()[:24].upper()


def collect_swift_files():
    files = sorted(SRC_ROOT.rglob("*.swift"))
    return [f.relative_to(ROOT).as_posix() for f in files]


def collect_sample_media():
    media_dir = SRC_ROOT / "Resources" / "SampleMedia"
    if not media_dir.exists():
        return []
    files = sorted(p for p in media_dir.iterdir() if p.is_file() and not p.name.startswith("."))
    return [f.relative_to(ROOT).as_posix() for f in files]


def build_pbxproj():
    swift_files = collect_swift_files()
    sample_media = collect_sample_media()

    # Core IDs
    project_id = uid("project:TikTokDesktop")
    main_group_id = uid("group:main")
    src_group_id = uid("group:TikTokDesktop")
    products_group_id = uid("group:Products")
    frameworks_group_id = uid("group:Frameworks")

    app_product_id = uid("product:TikTokDesktop.app")
    app_target_id = uid("target:TikTokDesktop")

    sources_phase_id = uid("phase:sources")
    frameworks_phase_id = uid("phase:frameworks")
    resources_phase_id = uid("phase:resources")

    proj_config_list_id = uid("configlist:project")
    proj_debug_id = uid("config:project:Debug")
    proj_release_id = uid("config:project:Release")

    target_config_list_id = uid("configlist:target")
    target_debug_id = uid("config:target:Debug")
    target_release_id = uid("config:target:Release")

    assets_ref_id = uid("fileref:Assets.xcassets")
    assets_build_id = uid("buildfile:Assets.xcassets")
    info_plist_ref_id = uid("fileref:Info.plist")
    entitlements_ref_id = uid("fileref:TikTokDesktop.entitlements")
    sample_media_folder_ref_id = uid("fileref:SampleMedia")
    sample_media_build_id = uid("buildfile:SampleMedia")

    # Build PBXFileReference and PBXBuildFile entries
    file_refs = []
    build_files = []
    source_build_ids = []
    resource_build_ids = [assets_build_id, sample_media_build_id]

    # Group tree for TikTokDesktop/
    groups = {}  # rel_dir -> {"children": [...], "name": ...}

    def ensure_group(rel_dir: str):
        if rel_dir in groups:
            return
        parent = os.path.dirname(rel_dir)
        name = os.path.basename(rel_dir)
        groups[rel_dir] = {"id": uid(f"group:{rel_dir}"), "name": name, "children": []}
        if parent and parent != rel_dir:
            ensure_group(parent)
            if groups[rel_dir]["id"] not in groups[parent]["children"]:
                groups[parent]["children"].append(groups[rel_dir]["id"])

    groups["TikTokDesktop"] = {"id": src_group_id, "name": "TikTokDesktop", "children": []}

    for rel_path in swift_files:
        fref_id = uid(f"fileref:{rel_path}")
        bfile_id = uid(f"buildfile:{rel_path}")
        name = os.path.basename(rel_path)
        parent = os.path.dirname(rel_path)
        ensure_group(parent)
        groups[parent]["children"].append(fref_id)

        file_refs.append(
            f'\t\t{fref_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = "{name}"; path = "{rel_path}"; sourceTree = SOURCE_ROOT; }};'
        )
        build_files.append(
            f'\t\t{bfile_id} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref_id} /* {name} */; }};'
        )
        source_build_ids.append((bfile_id, name))

    # Register Resources group entries
    ensure_group("TikTokDesktop/Resources")
    groups["TikTokDesktop/Resources"]["children"].extend([
        assets_ref_id,
        sample_media_folder_ref_id,
        info_plist_ref_id,
        entitlements_ref_id,
    ])

    file_refs.extend([
        f'\t\t{app_product_id} /* TikTokDesktop.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = TikTokDesktop.app; sourceTree = BUILT_PRODUCTS_DIR; }};',
        f'\t\t{assets_ref_id} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; name = Assets.xcassets; path = "TikTokDesktop/Resources/Assets.xcassets"; sourceTree = SOURCE_ROOT; }};',
        f'\t\t{sample_media_folder_ref_id} /* SampleMedia */ = {{isa = PBXFileReference; lastKnownFileType = folder; name = SampleMedia; path = "TikTokDesktop/Resources/SampleMedia"; sourceTree = SOURCE_ROOT; }};',
        f'\t\t{info_plist_ref_id} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = Info.plist; path = "TikTokDesktop/Resources/Info.plist"; sourceTree = SOURCE_ROOT; }};',
        f'\t\t{entitlements_ref_id} /* TikTokDesktop.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; name = TikTokDesktop.entitlements; path = "TikTokDesktop/Resources/TikTokDesktop.entitlements"; sourceTree = SOURCE_ROOT; }};',
    ])

    build_files.extend([
        f'\t\t{assets_build_id} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref_id} /* Assets.xcassets */; }};',
        f'\t\t{sample_media_build_id} /* SampleMedia in Resources */ = {{isa = PBXBuildFile; fileRef = {sample_media_folder_ref_id} /* SampleMedia */; }};',
    ])

    # Format PBXGroup entries
    group_entries = []
    group_entries.append(
        f"""\t\t{main_group_id} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{src_group_id} /* TikTokDesktop */,
\t\t\t\t{products_group_id} /* Products */,
\t\t\t\t{frameworks_group_id} /* Frameworks */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};"""
    )
    group_entries.append(
        f"""\t\t{products_group_id} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{app_product_id} /* TikTokDesktop.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};"""
    )
    group_entries.append(
        f"""\t\t{frameworks_group_id} /* Frameworks */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t);
\t\t\tname = Frameworks;
\t\t\tsourceTree = "<group>";
\t\t}};"""
    )

    for rel_dir in sorted(groups.keys()):
        g = groups[rel_dir]
        children_str = "\n".join(f"\t\t\t\t{cid}," for cid in g["children"])
        group_entries.append(
            f"""\t\t{g["id"]} /* {g["name"]} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children_str}
\t\t\t);
\t\t\tname = "{g["name"]}";
\t\t\tsourceTree = "<group>";
\t\t}};"""
        )

    sources_files_list = "\n".join(
        f"\t\t\t\t{bid} /* {name} in Sources */," for bid, name in source_build_ids
    )
    resources_files_list = "\n".join(
        f"\t\t\t\t{bid}," for bid in resource_build_ids
    )

    pbxproj = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{frameworks_phase_id} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{chr(10).join(group_entries)}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{app_target_id} /* TikTokDesktop */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {target_config_list_id} /* Build configuration list for PBXNativeTarget "TikTokDesktop" */;
\t\t\tbuildPhases = (
\t\t\t\t{sources_phase_id} /* Sources */,
\t\t\t\t{frameworks_phase_id} /* Frameworks */,
\t\t\t\t{resources_phase_id} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = TikTokDesktop;
\t\t\tproductName = TikTokDesktop;
\t\t\tproductReference = {app_product_id} /* TikTokDesktop.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{project_id} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t}};
\t\t\tbuildConfigurationList = {proj_config_list_id} /* Build configuration list for PBXProject "TikTokDesktop" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {main_group_id};
\t\t\tproductRefGroup = {products_group_id} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{app_target_id} /* TikTokDesktop */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{resources_phase_id} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{resources_files_list}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{sources_phase_id} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{sources_files_list}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{proj_debug_id} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{proj_release_id} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{target_debug_id} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "TikTokDesktop/Resources/TikTokDesktop.entitlements";
\t\t\t\tCODE_SIGN_IDENTITY = "-";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_HARDENED_RUNTIME = NO;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = "TikTokDesktop/Resources/Info.plist";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.tiktokdesktop.mac;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{target_release_id} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "TikTokDesktop/Resources/TikTokDesktop.entitlements";
\t\t\t\tCODE_SIGN_IDENTITY = "-";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_HARDENED_RUNTIME = NO;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = "TikTokDesktop/Resources/Info.plist";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.tiktokdesktop.mac;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{proj_config_list_id} /* Build configuration list for PBXProject "TikTokDesktop" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{proj_debug_id} /* Debug */,
\t\t\t\t{proj_release_id} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{target_config_list_id} /* Build configuration list for PBXNativeTarget "TikTokDesktop" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{target_debug_id} /* Debug */,
\t\t\t\t{target_release_id} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = {project_id} /* Project object */;
}}
"""

    PROJ_DIR.mkdir(parents=True, exist_ok=True)
    SCHEME_DIR.mkdir(parents=True, exist_ok=True)
    (PROJ_DIR / "project.pbxproj").write_text(pbxproj, encoding="utf-8")

    scheme_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target_id}"
               BuildableName = "TikTokDesktop.app"
               BlueprintName = "TikTokDesktop"
               ReferencedContainer = "container:TikTokDesktop.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target_id}"
            BuildableName = "TikTokDesktop.app"
            BlueprintName = "TikTokDesktop"
            ReferencedContainer = "container:TikTokDesktop.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
</Scheme>
"""
    (SCHEME_DIR / "TikTokDesktop.xcscheme").write_text(scheme_xml, encoding="utf-8")
    print(f"Generated TikTokDesktop.xcodeproj with {len(swift_files)} Swift files and {len(sample_media)} sample media assets.")


if __name__ == "__main__":
    build_pbxproj()
