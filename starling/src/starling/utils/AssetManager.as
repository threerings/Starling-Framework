package starling.utils
{
    import flash.display.Bitmap;
    import flash.display.Loader;
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.events.ProgressEvent;
    import flash.media.Sound;
    import flash.media.SoundChannel;
    import flash.media.SoundTransform;
    import flash.net.FileReference;
    import flash.net.URLLoader;
    import flash.net.URLLoaderDataFormat;
    import flash.net.URLRequest;
    import flash.system.ImageDecodingPolicy;
    import flash.system.LoaderContext;
    import flash.utils.ByteArray;
    import flash.utils.Dictionary;
    import flash.utils.clearTimeout;
    import flash.utils.describeType;
    import flash.utils.getQualifiedClassName;
    import flash.utils.setTimeout;
    
    import starling.core.Starling;
    import starling.text.BitmapFont;
    import starling.text.TextField;
    import starling.textures.AtfData;
    import starling.textures.Texture;
    import starling.textures.TextureAtlas;
    
    /** The AssetManager handles loading and accessing a variety of asset types. You can 
     *  add assets directly (via the 'add...' methods) or asynchronously via a queue. This allows
     *  you to deal with assets in a unified way, no matter if they are loaded from a file, 
     *  directory, URL, or from an embedded object.
     *  
     *  <p>If you load files from disk, the following types are supported:
     *  <code>png, jpg, atf, mp3, xml, fnt</code></p>
     */    
    public class AssetManager
    {
        private const SUPPORTED_EXTENSIONS:Vector.<String> = 
            new <String>["png", "jpg", "jpeg", "atf", "mp3", "xml", "fnt"]; 
        
        private var mScaleFactor:Number;
        private var mUseMipMaps:Boolean;
        private var mCheckPolicyFile:Boolean;
        private var mVerbose:Boolean;
        
        private var mRawAssets:Array;
        private var mTextures:Dictionary;
        private var mAtlases:Dictionary;
        private var mSounds:Dictionary;
        
        /** helper objects */
        private var sNames:Vector.<String> = new <String>[];
        
        /** Create a new AssetManager. The 'scaleFactor' and 'useMipmaps' parameters define
         *  how enqueued bitmaps will be converted to textures. */
        public function AssetManager(scaleFactor:Number=1, useMipmaps:Boolean=false)
        {
            mVerbose = false;
            mScaleFactor = scaleFactor > 0 ? scaleFactor : Starling.contentScaleFactor;
            mUseMipMaps = useMipmaps;
            mCheckPolicyFile = false;
            mRawAssets = [];
            mTextures = new Dictionary();
            mAtlases = new Dictionary();
            mSounds = new Dictionary();
        }
        
        /** Disposes all contained textures. */
        public function dispose():void
        {
            for each (var texture:Texture in mTextures)
                texture.dispose();
            
            for each (var atlas:TextureAtlas in mAtlases)
                atlas.dispose();
        }
        
        // retrieving
        
        /** Returns a texture with a certain name. The method first looks through the directly
         *  added textures; if no texture with that name is found, it scans through all 
         *  texture atlases. */
        public function getTexture(name:String):Texture
        {
            if (name in mTextures) return mTextures[name];
            else
            {
                for each (var atlas:TextureAtlas in mAtlases)
                {
                    var texture:Texture = atlas.getTexture(name);
                    if (texture) return texture;
                }
                return null;
            }
        }
        
        /** Returns all textures that start with a certain string, sorted alphabetically
         *  (especially useful for "MovieClip"). */
        public function getTextures(prefix:String="", result:Vector.<Texture>=null):Vector.<Texture>
        {
            if (result == null) result = new <Texture>[];
            
            for each (var name:String in getTextureNames(prefix, sNames))
                result.push(getTexture(name));
            
            sNames.length = 0;
            return result;
        }
        
        /** Returns all texture names that start with a certain string, sorted alphabetically. */
        public function getTextureNames(prefix:String="", result:Vector.<String>=null):Vector.<String>
        {
            if (result == null) result = new <String>[];
            
            for (var name:String in mTextures)
                if (name.indexOf(prefix) == 0)
                    result.push(name);                
            
            for each (var atlas:TextureAtlas in mAtlases)
                atlas.getNames(prefix, result);
            
            result.sort(Array.CASEINSENSITIVE);
            return result;
        }
        
        /** Returns a texture atlas with a certain name, or null if it's not found. */
        public function getTextureAtlas(name:String):TextureAtlas
        {
            return mAtlases[name] as TextureAtlas;
        }
        
        /** Returns a sound with a certain name. */
        public function getSound(name:String):Sound
        {
            return mSounds[name];
        }
        
        /** Returns all sound names that start with a certain string, sorted alphabetically. */
        public function getSoundNames(prefix:String=""):Vector.<String>
        {
            var names:Vector.<String> = new <String>[];
            
            for (var name:String in mSounds)
                if (name.indexOf(prefix) == 0)
                    names.push(name);
            
            return names.sort(Array.CASEINSENSITIVE);
        }
        
        /** Generates a new SoundChannel object to play back the sound. This method returns a 
         *  SoundChannel object, which you can access to stop the sound and to control volume. */ 
        public function playSound(name:String, startTime:Number=0, loops:int=0, 
                                  transform:SoundTransform=null):SoundChannel
        {
            if (name in mSounds)
                return getSound(name).play(startTime, loops, transform);
            else 
                return null;
        }
        
        // direct adding
        
        /** Register a texture under a certain name. It will be availble right away. */
        public function addTexture(name:String, texture:Texture):void
        {
            log("Adding texture '" + name + "'");
            
            if (name in mTextures)
                log("Warning: name was already in use; the previous texture will be replaced.");
            
            mTextures[name] = texture;
        }
        
        /** Register a texture atlas under a certain name. It will be availble right away. */
        public function addTextureAtlas(name:String, atlas:TextureAtlas):void
        {
            log("Adding texture atlas '" + name + "'");
            
            if (name in mAtlases)
                log("Warning: name was already in use; the previous atlas will be replaced.");
            
            mAtlases[name] = atlas;
        }
        
        /** Register a sound under a certain name. It will be availble right away. */
        public function addSound(name:String, sound:Sound):void
        {
            log("Adding sound '" + name + "'");
            
            if (name in mSounds)
                log("Warning: name was already in use; the previous sound will be replaced.");

            mSounds[name] = sound;
        }
        
        // removing
        
        /** Removes a certain texture, optionally disposing it. */
        public function removeTexture(name:String, dispose:Boolean=true):void
        {
            if (dispose && name in mTextures)
                mTextures[name].dispose();
            
            delete mTextures[name];
        }
        
        /** Removes a certain texture atlas, optionally disposing it. */
        public function removeTextureAtlas(name:String, dispose:Boolean=true):void
        {
            if (dispose && name in mAtlases)
                mAtlases[name].dispose();
            
            delete mAtlases[name];
        }
        
        /** Removes a certain sound. */
        public function removeSound(name:String):void
        {
            delete mSounds[name];
        }
        
        /** Removes assets of all types and empties the queue. */
        public function purge():void
        {
            for each (var texture:Texture in mTextures)
                texture.dispose();
            
            for each (var atlas:TextureAtlas in mAtlases)
                atlas.dispose();
            
            mRawAssets.length = 0;
            mTextures = new Dictionary();
            mAtlases = new Dictionary();
            mSounds = new Dictionary();
        }
        
        // queued adding
        
        /** Enqueues one or more raw assets; they will only be available after successfully 
         *  executing the "loadQueue" method. This method accepts a variety of different objects:
         *  
         *  <ul>
         *    <li>Strings containing an URL to a local or remote resource. Supported types:
         *        <code>png, jpg, atf, mp3, fnt, xml</code> (texture atlas).</li>
         *    <li>Instances of the File class (AIR only) pointing to a directory or a file.
         *        Directories will be scanned recursively for all supported types.</li>
         *    <li>Classes that contain <code>static</code> embedded assets.</li>
         *  </ul>
         *  
         *  Suitable object names are extracted automatically: A file named "image.png" will be
         *  accessible under the name "image". When enqueuing embedded assets via a class, 
         *  the variable name of the embedded object will be used as its name. An exception
         *  are texture atlases: they will have the same name as the actual texture they are
         *  referencing.
         */
        public function enqueue(...rawAssets):void
        {
            for each (var rawAsset:Object in rawAssets)
            {
                if (rawAsset is Array)
                {
                    enqueue.apply(this, rawAsset);
                }
                else if (rawAsset is Class)
                {
                    var typeXml:XML = describeType(rawAsset);
                    var childNode:XML;
                    
                    if (mVerbose)
                        log("Looking for static embedded assets in '" + 
                            (typeXml.@name).split("::").pop() + "'"); 
                    
                    for each (childNode in typeXml.constant.(@type == "Class"))
                        enqueueWithName(rawAsset[childNode.@name], childNode.@name);
                    
                    for each (childNode in typeXml.variable.(@type == "Class"))
                        enqueueWithName(rawAsset[childNode.@name], childNode.@name);
                }
                else if (getQualifiedClassName(rawAsset) == "flash.filesystem::File")
                {
                    if (!rawAsset["exists"])
                    {
                        log("File or directory not found: '" + rawAsset["url"] + "'");
                    }
                    else if (!rawAsset["isHidden"])
                    {
                        if (rawAsset["isDirectory"])
                            enqueue.apply(this, rawAsset["getDirectoryListing"]());
                        else
                        {
                            var extension:String = rawAsset["extension"].toLowerCase();
                            if (SUPPORTED_EXTENSIONS.indexOf(extension) != -1)
                                enqueueWithName(rawAsset["url"]);
                            else
                                log("Ignoring unsupported file '" + rawAsset["name"] + "'");
                        }
                    }
                }
                else if (rawAsset is String)
                {
                    enqueueWithName(rawAsset);
                }
                else
                {
                    log("Ignoring unsupported asset type: " + getQualifiedClassName(rawAsset));
                }
            }
        }
        
        /** Enqueues a single asset with a custom name that can be used to access it later. 
         *  If you don't pass a name, it's attempted to generate it automatically.
         *  @returns the name under which the asset was registered. */
        public function enqueueWithName(asset:Object, name:String=null):String
        {
            if (name == null) name = getName(asset);
            log("Enqueuing '" + name + "'");
            
            mRawAssets.push({
                name: name,
                asset: asset
            });
            
            return name;
        }
        
        /** Loads all enqueued assets asynchronously. The 'onProgress' function will be called
         *  with a 'ratio' between '0.0' and '1.0', with '1.0' meaning that it's complete.
         *
         *  @param onProgress: <code>function(ratio:Number):void;</code> 
         */
        public function loadQueue(onProgress:Function):void
        {
            if (Starling.context == null)
                throw new Error("The Starling instance needs to be ready before textures can be loaded.");
            
            var xmls:Vector.<XML> = new <XML>[];
            var numElements:int = mRawAssets.length;
            var currentRatio:Number = 0.0;
            var timeoutID:uint;
            
            resume();
            
            function resume():void
            {
                currentRatio = mRawAssets.length ? 1.0 - (mRawAssets.length / numElements) : 1.0;
                
                if (mRawAssets.length)
                    timeoutID = setTimeout(processNext, 1);
                else
                    processXmls();
                
                if (onProgress != null)
                    onProgress(currentRatio);
            }
            
            function processNext():void
            {
                var assetInfo:Object = mRawAssets.pop();
                clearTimeout(timeoutID);
                processRawAsset(assetInfo.name, assetInfo.asset, xmls, progress, resume);
            }
            
            function processXmls():void
            {
                // xmls are processed seperately at the end, because the textures they reference
                // have to be available for other XMLs. Texture atlases are processed first:
                // that way, their textures can be referenced, too.
                
                xmls.sort(function(a:XML, b:XML):int { 
                    return a.localName() == "TextureAtlas" ? -1 : 1; 
                });
                
                for each (var xml:XML in xmls)
                {
                    var name:String;
                    var rootNode:String = xml.localName();
                    
                    if (rootNode == "TextureAtlas")
                    {
                        name = getName(xml.@imagePath.toString());
                        
                        var atlasTexture:Texture = getTexture(name);
                        addTextureAtlas(name, new TextureAtlas(atlasTexture, xml));
                        removeTexture(name, false);
                    }
                    else if (rootNode == "font")
                    {
                        name = getName(xml.pages.page.@file.toString());
                        
                        var fontTexture:Texture = getTexture(name);
                        TextField.registerBitmapFont(new BitmapFont(fontTexture, xml));
                        removeTexture(name, false);
                    }
                    else
                        throw new Error("XML contents not recognized: " + rootNode);
                }
            }
            
            function progress(ratio:Number):void
            {
                onProgress(currentRatio + (1.0 / numElements) * Math.min(1.0, ratio) * 0.99);
            }
        }
        
        private function processRawAsset(name:String, rawAsset:Object, xmls:Vector.<XML>,
                                         onProgress:Function, onComplete:Function):void
        {
            loadRawAsset(name, rawAsset, onProgress, function(asset:Object):void
            {
                var texture:Texture;
                var bytes:ByteArray;
                
                if (asset is Sound)
                {
                    addSound(name, asset as Sound);
                    onComplete();
                }
                else if (asset is Bitmap)
                {
                    texture = Texture.fromBitmap(asset as Bitmap, mUseMipMaps, false, mScaleFactor);
                    texture.root.onRestore = function():void
                    {
                        loadRawAsset(name, rawAsset, null, function(asset:Object):void
                        {
                            texture.root.uploadBitmap(asset as Bitmap);
                        });
                    };

                    addTexture(name, texture);
                    onComplete();
                }
                else if (asset is ByteArray)
                {
                    bytes = asset as ByteArray;
                    
                    if (AtfData.isAtfData(bytes))
                    {
                        texture = Texture.fromAtfData(bytes, mScaleFactor, mUseMipMaps, onComplete);
                        texture.root.onRestore = function():void
                        {
                            loadRawAsset(name, rawAsset, null, function(asset:Object):void
                            {
                                texture.root.uploadAtfData(asset as ByteArray, 0, true);
                            });
                        };
                        
                        addTexture(name, texture);
                    }
                    else
                    {
                        xmls.push(new XML(bytes));
                        onComplete();
                    }
                }
                else if (asset is XML)
                {
                    xmls.push(new XML(bytes));
                    onComplete();
                }
                else if (asset == null)
                {
                    onComplete();
                }
                else
                {
                    log("Ignoring unsupported asset type: " + getQualifiedClassName(asset));
                    onComplete();
                }
                
                // avoid that objects stay in memory (through 'onRestore' functions)
                asset = null;
                bytes = null;
            });
        }
        
        private function loadRawAsset(name:String, rawAsset:Object, 
                                      onProgress:Function, onComplete:Function):void
        {
            var extension:String = null;
            
            if (rawAsset is Class)
            {
                onComplete(new rawAsset());
            }
            else if (rawAsset is String)
            {
                var url:String = rawAsset as String;
                extension = url.split(".").pop().toLowerCase().split("?")[0];
                
                var urlLoader:URLLoader = new URLLoader();
                urlLoader.dataFormat = URLLoaderDataFormat.BINARY;
                urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
                urlLoader.addEventListener(ProgressEvent.PROGRESS, onLoadProgress);
                urlLoader.addEventListener(Event.COMPLETE, onUrlLoaderComplete);
                urlLoader.load(new URLRequest(url));
            }
            
            function onIoError(event:IOErrorEvent):void
            {
                log("IO error: " + event.text);
                onComplete(null);
            }
            
            function onLoadProgress(event:ProgressEvent):void
            {
                if (onProgress != null)
                    onProgress(event.bytesLoaded / event.bytesTotal);
            }
            
            function onUrlLoaderComplete(event:Event):void
            {
                var urlLoader:URLLoader = event.target as URLLoader;
                var bytes:ByteArray = urlLoader.data as ByteArray;
                var sound:Sound;
                
                urlLoader.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
                urlLoader.removeEventListener(ProgressEvent.PROGRESS, onLoadProgress);
                urlLoader.removeEventListener(Event.COMPLETE, onUrlLoaderComplete);
                
                switch (extension)
                {
                    case "atf":
                    case "fnt":
                    case "xml":
                        onComplete(bytes);
                        break;
                    case "mp3":
                        sound = new Sound();
                        sound.loadCompressedDataFromByteArray(bytes, bytes.length);
                        onComplete(sound);
                        break;
                    default:
                        var loaderContext:LoaderContext = new LoaderContext(mCheckPolicyFile);
                        var loader:Loader = new Loader();
                        loaderContext.imageDecodingPolicy = ImageDecodingPolicy.ON_LOAD;
                        loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoaderComplete);
                        loader.loadBytes(urlLoader.data as ByteArray, loaderContext);
                        break;
                }
            }
            
            function onLoaderComplete(event:Event):void
            {
                event.target.removeEventListener(Event.COMPLETE, onLoaderComplete);
                onComplete(event.target.content);
            }
        }
        
        // helpers
        
        /** This method is called by 'enqueue' to determine the name under which an asset will be
         *  accessible; override it if you need a custom naming scheme. Typically, 'rawAsset' is 
         *  either a String or a FileReference. Note that this method won't be called for embedded
         *  assets. */
        protected function getName(rawAsset:Object):String
        {
            var matches:Array;
            var name:String;
            
            if (rawAsset is String || rawAsset is FileReference)
            {
                name = rawAsset is String ? rawAsset as String : (rawAsset as FileReference).name;
                name = name.replace(/%20/g, " "); // URLs use '%20' for spaces
                matches = /(.*[\\\/])?([\w\s\-]+)(\.[\w]{1,4})?/.exec(name);
                
                if (matches && matches.length == 4) return matches[2];
                else throw new ArgumentError("Could not extract name from String '" + rawAsset + "'");
            }
            else
            {
                name = getQualifiedClassName(rawAsset);
                throw new ArgumentError("Cannot extract names for objects of type '" + name + "'");
            }
        }
        
        private function log(message:String):void
        {
            if (verbose) trace("[AssetManager]", message);
        }
        
        // properties
        
        /** When activated, the class will trace information about added/enqueued assets. */
        public function get verbose():Boolean { return mVerbose; }
        public function set verbose(value:Boolean):void { mVerbose = value; }
        
        /** For bitmap textures, this flag indicates if mip maps should be generated when they 
         *  are loaded; for ATF textures, it indicates if mip maps are valid and should be
         *  used. */
        public function get useMipMaps():Boolean { return mUseMipMaps; }
        public function set useMipMaps(value:Boolean):void { mUseMipMaps = value; }
        
        /** Textures that are created from Bitmaps or ATF files will have the scale factor 
         *  assigned here. */
        public function get scaleFactor():Number { return mScaleFactor; }
        public function set scaleFactor(value:Number):void { mScaleFactor = value; }
        
        /** Specifies whether a check should be made for the existence of a URL policy file before
         *  loading an object from a remote server. More information about this topic can be found 
         *  in the 'flash.system.LoaderContext' documentation. */
        public function get checkPolicyFile():Boolean { return mCheckPolicyFile; }
        public function set checkPolicyFile(value:Boolean):void { mCheckPolicyFile = value; }
    }
}
