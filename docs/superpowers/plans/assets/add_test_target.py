#!/usr/bin/env python3
# Tangomiru.xcodeproj に Swift Testing 用の TangomiruTests ターゲットと共有スキームを追加する。
# 使い方: python3 docs/superpowers/plans/assets/add_test_target.py .

import re, sys, pathlib
p = pathlib.Path(sys.argv[1]) / "Tangomiru.xcodeproj/project.pbxproj"
s = p.read_text()
if "TangomiruTests" in s:
    sys.exit("already added")
T, PROD, GRP, SRC, FW, RES, CFGL, DBG, REL, DEP, PROXY = [f"05E79FD{i:X}306C72C100640B04" for i in range(11)]
def ins(section, text):
    global s
    marker = f"/* End {section} section */"
    if marker not in s:
        s = s.replace("/* Begin PBXFileReference section */", f"/* Begin {section} section */\n/* End {section} section */\n\n/* Begin PBXFileReference section */")
    s = s.replace(marker, text + marker)
ins("PBXContainerItemProxy", f"""		{PROXY} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = 05E79FBA306C72C000640B04 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = 05E79FC1306C72C000640B04;
			remoteInfo = Tangomiru;
		}};
""")
ins("PBXFileReference", f"""		{PROD} /* TangomiruTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = TangomiruTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
""")
ins("PBXFileSystemSynchronizedRootGroup", f"""		{GRP} /* TangomiruTests */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			path = TangomiruTests;
			sourceTree = "<group>";
		}};
""")
ins("PBXFrameworksBuildPhase", f"""		{FW} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
""")
s = s.replace("""				05E79FC4306C72C000640B04 /* Tangomiru */,
				05E79FC3306C72C000640B04 /* Products */,""", f"""				05E79FC4306C72C000640B04 /* Tangomiru */,
				{GRP} /* TangomiruTests */,
				05E79FC3306C72C000640B04 /* Products */,""")
s = s.replace("""				05E79FC2306C72C000640B04 /* Tangomiru.app */,
			);""", f"""				05E79FC2306C72C000640B04 /* Tangomiru.app */,
				{PROD} /* TangomiruTests.xctest */,
			);""")
ins("PBXNativeTarget", f"""		{T} /* TangomiruTests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {CFGL} /* Build configuration list for PBXNativeTarget "TangomiruTests" */;
			buildPhases = (
				{SRC} /* Sources */,
				{FW} /* Frameworks */,
				{RES} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				{DEP} /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				{GRP} /* TangomiruTests */,
			);
			name = TangomiruTests;
			packageProductDependencies = (
			);
			productName = TangomiruTests;
			productReference = {PROD} /* TangomiruTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		}};
""")
s = s.replace("""					05E79FC1306C72C000640B04 = {
						CreatedOnToolsVersion = 26.3;
					};""", f"""					05E79FC1306C72C000640B04 = {{
						CreatedOnToolsVersion = 26.3;
					}};
					{T} = {{
						CreatedOnToolsVersion = 26.3;
						TestTargetID = 05E79FC1306C72C000640B04;
					}};""")
s = s.replace("""				05E79FC1306C72C000640B04 /* Tangomiru */,
			);
		};
/* End PBXProject section */""", f"""				05E79FC1306C72C000640B04 /* Tangomiru */,
				{T} /* TangomiruTests */,
			);
		}};
/* End PBXProject section */""")
ins("PBXResourcesBuildPhase", f"""		{RES} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
""")
ins("PBXSourcesBuildPhase", f"""		{SRC} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
""")
if "/* Begin PBXTargetDependency section */" not in s:
    s = s.replace("/* Begin XCBuildConfiguration section */", "/* Begin PBXTargetDependency section */\n/* End PBXTargetDependency section */\n\n/* Begin XCBuildConfiguration section */")
ins("PBXTargetDependency", f"""		{DEP} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = 05E79FC1306C72C000640B04 /* Tangomiru */;
			targetProxy = {PROXY} /* PBXContainerItemProxy */;
		}};
""")
def cfg(id_, name):
    return f"""		{id_} /* {name} */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 24BSY9Z4H5;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 26.2;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = harumidiv.TangomiruTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				STRING_CATALOG_GENERATE_SYMBOLS = NO;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Tangomiru.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Tangomiru";
			}};
			name = {name};
		}};
"""
ins("XCBuildConfiguration", cfg(DBG, "Debug") + cfg(REL, "Release"))
ins("XCConfigurationList", f"""		{CFGL} /* Build configuration list for PBXNativeTarget "TangomiruTests" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{DBG} /* Debug */,
				{REL} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
""")
p.write_text(s)
scheme_dir = pathlib.Path(sys.argv[1]) / "Tangomiru.xcodeproj/xcshareddata/xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
(scheme_dir / "Tangomiru.xcscheme").write_text(f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2630" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "05E79FC1306C72C000640B04" BuildableName = "Tangomiru.app" BlueprintName = "Tangomiru" ReferencedContainer = "container:Tangomiru.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO" parallelizable = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{T}" BuildableName = "TangomiruTests.xctest" BlueprintName = "TangomiruTests" ReferencedContainer = "container:Tangomiru.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "05E79FC1306C72C000640B04" BuildableName = "Tangomiru.app" BlueprintName = "Tangomiru" ReferencedContainer = "container:Tangomiru.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
""")
print("ok")
