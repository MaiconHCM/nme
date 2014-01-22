package platforms;

import haxe.io.Path;
import haxe.Template;
import sys.io.File;
import sys.FileSystem;
import PlatformConfig;

class IOSView extends Platform
{
   var component:String;
   var valid_archs:Array<String>;

   public function new(inProject:NMEProject, inComponent:String)
   {
      super(inProject);
      component = inComponent;
   }


   override public function build():Void 
   {
      var context = generateContext();

      var nmeLib = new Haxelib("nme");

      var targetDirectory = PathHelper.combine(project.app.path, "ios");
      var name = project.app.file;
      //var outputDirectory = '$targetDirectory/$name.framework/';
      var outputDirectory = '$targetDirectory/$name/';
      var buildDir = targetDirectory + "/build/";


      //for(asset in project.assets) 
      //   asset.resourceName = asset.flatName;


      PathHelper.mkdir(targetDirectory);
      PathHelper.mkdir(outputDirectory);


/*
      PathHelper.mkdir(outputDirectory + "/Versions");
      PathHelper.mkdir(outputDirectory + "/Versions/A");
      PathHelper.mkdir(outputDirectory + "/Versions/A/Headers");
      PathHelper.mkdir(outputDirectory + "/Versions/A/Resources");
*/

      PathHelper.mkdir(buildDir);
      PathHelper.mkdir(buildDir + "/cpp");

      FileHelper.copyFileTemplate(project.templatePaths, "ios-view/FrameworkInterface.mm", buildDir+"/cpp/FrameworkInterface.mm", context);
      //FileHelper.copyFileTemplate(project.templatePaths, "ios-view/Info.plist", outputDirectory+"/Versions/A/Resources/Info.plist", context);
      FileHelper.recursiveCopyTemplate(project.templatePaths, "ios-view/build", buildDir, context);
      FileHelper.recursiveCopyTemplate(project.templatePaths, "haxe/nme", buildDir+"/nme", context);
      FileHelper.copyFileTemplate(project.templatePaths, "ios-view/HEADER.h", outputDirectory+"/"+name + ".h", context);
      FileHelper.copyFileTemplate(project.templatePaths, "ios-view/HEADER.h",  buildDir+"/cpp/FrameworkHeader.h", context);
      FileHelper.copyFileTemplate(project.templatePaths, "ios-view/CLASS.mm",  outputDirectory+"/"+name + ".mm", context);

      //ProcessHelper.runCommand(outputDirectory + "/Versions", "ln", [ "-s", "A", "Current"] );
      //ProcessHelper.runCommand(outputDirectory, "ln", [ "-s", "Versions/Current/Headers", "Headers"] );
      //ProcessHelper.runCommand(outputDirectory, "ln", [ "-s", "Versions/Current/Resources", "Resources"] );
      //ProcessHelper.runCommand(outputDirectory, "ln", [ "-s", "Versions/Current/" + name, name] );

      ProcessHelper.runCommand(buildDir, "make", [] );
   }

   override public function clean():Void 
   {
      #if false
      var targetPath = project.app.path + "/ios";

      if (FileSystem.exists(targetPath)) 
      {
         PathHelper.removeDirectory(targetPath);
      }
      #end
   }

   override public function display():Void 
   {
      #if false
      var hxml = PathHelper.findTemplate(project.templatePaths, "iphone/PROJ/haxe/Build.hxml");
      var template = new Template(File.getContent(hxml));
      Sys.println(template.execute(generateContext(project)));
      #end
   }

   override private function generateContext():Dynamic 
   {
      var targetDirectory = PathHelper.combine(project.app.path, "ios");
      var name = project.app.file;
      var outputDirectory = '$targetDirectory/$name/';
 

      project.sources = PathHelper.relocatePaths(project.sources, PathHelper.combine(project.app.path, "ios/build"));

      if (project.targetFlags.exists("xml")) 
      {
         project.haxeflags.push("-xml " + project.app.path + "/ios/types.xml");
      }
 
      if (project.debug)
         project.haxeflags.push("-debug");
 

      var context = project.templateContext;

      context.OBJC_ARC = false;
      context.COMPONENT = component;

      context.linkedLibraries = [];

      for(dependency in project.dependencies) 
      {
         if (!StringTools.endsWith(dependency, ".framework")) 
         {
            context.linkedLibraries.push(dependency);
         }
      }


      valid_archs = new Array<String>();
      var armv6 = false;
      var armv7 = false;
      var architectures = project.architectures;

      if (architectures == null || architectures.length == 0) 
      {
         architectures = [ Architecture.ARMV7, Architecture.ARMV7 ];
      }

      if (project.config.ios.device == IOSConfigDevice.UNIVERSAL || project.config.ios.device == IOSConfigDevice.IPHONE) 
      {
         if (project.config.ios.deployment < 5) 
         {
            ArrayHelper.addUnique(architectures, Architecture.ARMV6);
         }
      }

      for(architecture in project.architectures) 
      {
         switch(architecture) 
         {
            case ARMV6: valid_archs.push("armv6"); armv6 = true;
            case ARMV7: valid_archs.push("armv7"); armv7 = true;
            default:
         }
      }

      context.CURRENT_ARCHS = "( " + valid_archs.join(",") + ") ";

      valid_archs.push("i386");


      var libExts = new Array<String>();
      if (armv6) libExts.push(".iphoneos.a");
      if (armv7) libExts.push(".iphoneos-v7.a");
      libExts.push(".iphonesim.a");

      var appLibs = new Array<String>();
      var dbg = project.debug ? "-debug" : "";
      for(ext in libExts)
         appLibs.push("cpp/ApplicationMain" + dbg + ext);

      for(ndll in project.ndlls) 
      {
         if (ndll.haxelib != null) 
         {
            for(ext in libExts)
            {
               var releaseLib = PathHelper.getLibraryPath(ndll, "iPhone", "lib", ext);
               appLibs.push(releaseLib);
            }
         }
      }

   
      var buildDir = PathHelper.combine(project.app.path, "ios/build");
      context.VALID_ARCHS = valid_archs.join(" ");
      context.APP_LIBS = appLibs.join(" ");
      context.THUMB_SUPPORT = armv6 ? "GCC_THUMB_SUPPORT = NO;" : "";
      //context.DEST_PATH = PathHelper.relocatePath('$outputDirectory/Versions/A/$name', buildDir);
      context.DEST_PATH = PathHelper.relocatePath('$outputDirectory/lib$name.a', buildDir);
      context.ARMV6 = armv6;
      context.ARMV7 = armv7;
      context.CLASS_NAME = name;
      context.TARGET_DEVICES = switch(project.config.ios.device) { case UNIVERSAL: "1,2"; case IPHONE : "1"; case IPAD : "2"; }
      context.DEPLOYMENT = project.config.ios.deployment;

      if (project.config.ios.compiler == "llvm" || project.config.ios.compiler == "clang") 
      {
         context.OBJC_ARC = true;
      }

      context.IOS_COMPILER = project.config.ios.compiler;
      context.IOS_LINKER_FLAGS = project.config.ios.linkerFlags.split(" ").join(", ");

      context.RESOURCES = "";

      //updateIcon();
      //updateLaunchImage();
      return context;
   }

   override public function run(arguments:Array<String>):Void 
   {
      #if false
      IOSHelper.launch(project, PathHelper.combine(project.app.path, "ios"));
      #end
   }

   override public function update():Void 
   {
      #if false
      var nmeLib = new Haxelib("nme");

      //for(asset in project.assets) 
      //   asset.resourceName = asset.flatName;

      var context = generateContext(project);

      trace(valid_archs);

      var targetDirectory = PathHelper.combine(project.app.path, "ios");
      var projectDirectory = targetDirectory + "/" + project.app.file + "/";

      PathHelper.mkdir(targetDirectory);
      PathHelper.mkdir(projectDirectory);
      PathHelper.mkdir(projectDirectory + "/haxe");
      PathHelper.mkdir(projectDirectory + "/haxe/nme/installer");



      //SWFHelper.generateSWFClasses(project, projectDirectory + "/haxe");
      PathHelper.mkdir(projectDirectory + "/lib");

      for(archID in 0...3) 
      {
         var arch = [ "armv6", "armv7", "i386" ][archID];

         if (arch == "armv6" && !context.ARMV6)
            continue;

         if (arch == "armv7" && !context.ARMV7)
            continue;

         var libExt = [ ".iphoneos.a", ".iphoneos-v7.a", ".iphonesim.a" ][archID];

         PathHelper.mkdir(projectDirectory + "/lib/" + arch);
         PathHelper.mkdir(projectDirectory + "/lib/" + arch + "-debug");

         for(ndll in project.ndlls) 
         {
            if (ndll.haxelib != null) 
            {
               var releaseLib = PathHelper.getLibraryPath(ndll, "iPhone", "lib", libExt);
               var debugLib = PathHelper.getLibraryPath(ndll, "iPhone", "lib", libExt);
               var releaseDest = projectDirectory + "/lib/" + arch + "/lib" + ndll.name + ".a";
               var debugDest = projectDirectory + "/lib/" + arch + "-debug/lib" + ndll.name + ".a";

               FileHelper.copyIfNewer(releaseLib, releaseDest);

               if (FileSystem.exists(debugLib)) 
               {
                  FileHelper.copyIfNewer(debugLib, debugDest);

               } else if (FileSystem.exists(debugDest)) 
               {
                  FileSystem.deleteFile(debugDest);
               }
            }
         }
      }

      PathHelper.mkdir(projectDirectory + "/assets");

      for(asset in project.assets) 
      {
         if (asset.type != AssetType.TEMPLATE) 
         {
            PathHelper.mkdir(Path.directory(projectDirectory + "/assets/" + asset.flatName));
            FileHelper.copyIfNewer(asset.sourcePath, projectDirectory + "/assets/" + asset.flatName);
            FileHelper.copyIfNewer(asset.sourcePath, projectDirectory + "haxe/" + asset.sourcePath);
         }
         else
         {
            PathHelper.mkdir(Path.directory(projectDirectory + "/" + asset.targetPath));
            FileHelper.copyAsset(asset, projectDirectory + "/" + asset.targetPath, context);
         }
      }

        if (project.command == "update" && PlatformHelper.hostPlatform == Platform.MAC) 
        {
            ProcessHelper.runCommand("", "open", [ targetDirectory + "/" + project.app.file + ".xcodeproj" ] );
        }
     #end
   }

}
