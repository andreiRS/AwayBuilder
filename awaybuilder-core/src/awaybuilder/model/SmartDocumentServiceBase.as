package awaybuilder.model
{
	import away3d.cameras.Camera3D;
	import away3d.containers.ObjectContainer3D;
	import away3d.entities.Mesh;
	import away3d.entities.TextureProjector;
	import away3d.events.AssetEvent;
	import away3d.events.LoaderEvent;
	import away3d.library.AssetLibrary;
	import away3d.library.assets.AssetType;
	import away3d.library.assets.BitmapDataAsset;
	import away3d.lights.LightBase;
	import away3d.loaders.AssetLoader;
	import away3d.loaders.misc.AssetLoaderToken;
	import away3d.loaders.parsers.AWDParser;
	import away3d.loaders.parsers.Parsers;
	import away3d.loaders.parsers.utils.ParserUtil;
	import away3d.materials.MaterialBase;
	import away3d.materials.TextureMaterial;
	import away3d.materials.methods.EffectMethodBase;
	import away3d.primitives.SkyBox;
	import away3d.textures.Texture2DBase;
	
	import awaybuilder.controller.events.ErrorLogEvent;
	import awaybuilder.model.vo.DocumentVO;
	import awaybuilder.model.vo.scene.AssetVO;
	import awaybuilder.model.vo.scene.CubeTextureVO;
	import awaybuilder.model.vo.scene.GeometryVO;
	import awaybuilder.utils.logging.AwayBuilderLoadErrorLogger;
	
	import flash.display.Bitmap;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import mx.controls.Alert;
	import mx.core.FlexGlobals;
	import mx.managers.CursorManager;
	
	import org.robotlegs.mvcs.Actor;
	
	import spark.components.Application;
	
	public class SmartDocumentServiceBase extends Actor
	{
		
		[Inject]
		public var assets:AssetsModel;
		
		private var _document:DocumentVO;
		
		private var _objects:Vector.<ObjectContainer3D> = new Vector.<ObjectContainer3D>();
		private var _loaderToken:AssetLoaderToken;
		
		protected function loadBitmap( url:String  ):void
		{
			var loader:Loader = new Loader();             
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, loader_completeHander); 
			loader.load( new URLRequest(url) );
		}
		protected function parseBitmap( data:ByteArray ):void
		{
			var loader:Loader = new Loader();             
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, loader_completeHander); 
			loader.loadBytes( data );
		}
		private function loader_completeHander(event:Event):void
		{
			var loader:LoaderInfo = LoaderInfo( event.currentTarget );       
			bitmapReady(loader.content as Bitmap);
		}
		
		protected function loadAssets( url:String):void
		{
			_document = new DocumentVO();
			_objects.length = 0;
			
			AwayBuilderLoadErrorLogger.clearLog();
			
			Parsers.enableAllBundled();
			AssetLibrary.addEventListener(AssetEvent.ASSET_COMPLETE, assetCompleteHandler);		
			AssetLibrary.addEventListener(AssetEvent.TEXTURE_SIZE_ERROR, textureSizeErrorHandler);
			AssetLibrary.addEventListener(LoaderEvent.RESOURCE_COMPLETE, resourceCompleteHandler);
			AssetLibrary.addEventListener(LoaderEvent.LOAD_ERROR, loadErrorHandler);
			_loaderToken=AssetLibrary.load(new URLRequest(url));	
			_loaderToken.addEventListener(LoaderEvent.RESOURCE_COMPLETE, resourceCompleteHandlerToken);			
			
			CursorManager.setBusyCursor();
			Application(FlexGlobals.topLevelApplication).mouseEnabled = false;
		}
		
		protected function parse( data:ByteArray ):void
		{
			_document = new DocumentVO();
			_objects.length = 0;
			
			AwayBuilderLoadErrorLogger.clearLog();
			
			Parsers.enableAllBundled();
			AssetLibrary.addEventListener(AssetEvent.ASSET_COMPLETE, assetCompleteHandler);		
			AssetLibrary.addEventListener(AssetEvent.TEXTURE_SIZE_ERROR, textureSizeErrorHandler);
			AssetLibrary.addEventListener(LoaderEvent.RESOURCE_COMPLETE, resourceCompleteHandler);
			AssetLibrary.addEventListener(LoaderEvent.LOAD_ERROR, loadErrorHandler);
			_loaderToken=AssetLibrary.loadData(data);	
			_loaderToken.addEventListener(LoaderEvent.RESOURCE_COMPLETE, resourceCompleteHandlerToken);
			
			CursorManager.setBusyCursor();
			Application(FlexGlobals.topLevelApplication).mouseEnabled = false;
		}
		
		private function loadErrorHandler( event:LoaderEvent ):void
		{
			Alert.show( event.message, "Asset not loaded" );
		}
		
		private function textureSizeErrorHandler( event:AssetEvent ):void
		{
			var bdAsset:BitmapDataAsset = event.asset as BitmapDataAsset;
			AwayBuilderLoadErrorLogger.logError("WARN:"+bdAsset.name+" - Bitmap dimensions are not a power of 2 or larger than 2048. Size:"+bdAsset.bitmapData.width+"x"+bdAsset.bitmapData.height, { assetEvent:bdAsset });
		}
		
		private function resourceCompleteHandlerToken( event:LoaderEvent ):void
		{
			if(AssetLoader(event.target).baseDependency.data)
				if(AssetLoader(event.target).baseDependency.data is ByteArray)
					parseGlobalSettings(AssetLoader(event.target).baseDependency.data);
			_loaderToken.removeEventListener(LoaderEvent.RESOURCE_COMPLETE, resourceCompleteHandlerToken);
			documentReady( _document );	
			
		}
		
				
		private function resourceCompleteHandler( event:LoaderEvent ):void
		{
			AssetLibrary.removeEventListener(AssetEvent.ASSET_COMPLETE, assetCompleteHandler);		
			AssetLibrary.removeEventListener(AssetEvent.TEXTURE_SIZE_ERROR, textureSizeErrorHandler);
			AssetLibrary.removeEventListener(LoaderEvent.RESOURCE_COMPLETE, resourceCompleteHandler);
			AssetLibrary.removeEventListener(LoaderEvent.LOAD_ERROR, loadErrorHandler);
			
			for each( var o:ObjectContainer3D in _objects )
			{
				if( !o.parent )
				{
					_document.scene.addItem( assets.GetAsset( o ) );
				}
			}
			
			if (AwayBuilderLoadErrorLogger.log.length>0) {
				dispatch( new ErrorLogEvent(ErrorLogEvent.LOG_ENTRY_MADE));
			}
			
			
			CursorManager.removeBusyCursor();
			Application(FlexGlobals.topLevelApplication).mouseEnabled = true;
		}
		
		private function assetCompleteHandler( event:AssetEvent ):void
		{		
			switch( event.asset.assetType )
			{
				case AssetType.MESH:
					var mesh:Mesh = event.asset as Mesh;
					
					if( !mesh.material )
						mesh.material = assets.GetObject(assets.defaultMaterial) as MaterialBase;
					
					else{
						if (mesh.material is TextureMaterial)
							if (assets.checkIfMaterialIsDefault(TextureMaterial(mesh.material)))
								mesh.material = assets.GetObject(assets.defaultMaterial) as MaterialBase;							
					}
					var i:int;
					for (i=0;i<mesh.subMeshes.length;i++)	
						if (mesh.subMeshes[i].material is TextureMaterial)		
							if (assets.checkIfMaterialIsDefault(TextureMaterial(mesh.subMeshes[i].material)))
								mesh.subMeshes[i].material = assets.GetObject(assets.defaultMaterial) as MaterialBase;	
					
					if( !isGeometryInList( assets.GetAsset(mesh.geometry) as GeometryVO ) )
					{
						_document.geometry.addItem( assets.GetAsset(mesh.geometry) as GeometryVO );
					}
					_objects.push( mesh  );
					break;
				case AssetType.CONTAINER:
					var c:ObjectContainer3D = event.asset as ObjectContainer3D;
					_objects.push( c );
					break;
				case AssetType.CAMERA:
					var cam:Camera3D = event.asset as Camera3D;
					_objects.push( cam );
					break;
				case AssetType.TEXTURE_PROJECTOR:
					var tp:TextureProjector = event.asset as TextureProjector;
					if(tp.texture.name=="defaultTexture")tp.texture=assets.GetObject(assets.defaultTexture) as Texture2DBase;
					_objects.push( tp );
					break;
				case AssetType.SKYBOX:
					//To Do: Check if textures are Default
					var sb:SkyBox = event.asset as SkyBox;
					_objects.push( sb );
					break;
				case AssetType.EFFECTS_METHOD:
					assets.checkEffectMethodForDefaulttexture(event.asset as EffectMethodBase)
					_document.methods.addItem( assets.GetAsset( event.asset ) );
					break;	
				case AssetType.LIGHT:
					var light:LightBase = event.asset as LightBase;
					_objects.push( light );
					_document.lights.addItem( assets.GetAsset( event.asset ) );
					break;
				case AssetType.LIGHT_PICKER:
					_document.lights.addItem( assets.GetAsset( event.asset ) );
					break;
				case AssetType.MATERIAL:
					if(!( event.asset is TextureMaterial)){
						_document.materials.addItem( assets.GetAsset( event.asset ) );}
					else
						if (!assets.checkIfMaterialIsDefault(TextureMaterial(event.asset)))
							_document.materials.addItem( assets.GetAsset( event.asset ) );
					break;
				case AssetType.TEXTURE:
					if(event.asset.name!="defaultTexture")
						_document.textures.addItem( assets.GetAsset( event.asset ) );
					break;
				case AssetType.GEOMETRY:
					var geometry:GeometryVO = assets.GetAsset( event.asset ) as GeometryVO;
					if( !isGeometryInList( geometry ) )
					{
						_document.geometry.addItem( geometry );
					}
					break;
				case AssetType.ANIMATION_SET:
				case AssetType.ANIMATION_STATE:
				case AssetType.ANIMATION_NODE:
				case AssetType.SKELETON:
//				case AssetType.ANIMATOR:
//				case AssetType.SKELETON_POSE:
					_document.animations.addItem( assets.GetAsset( event.asset ) );
					break;
			}
		}
		
		private function parseGlobalSettings(byteData:ByteArray):void
		{
			byteData.position=0;
			var magicString:String=byteData.readUTFBytes(3);
			if (magicString=="AWD"){
				
				var awdVersionMajor:uint=byteData.readUnsignedByte();//_version[0]
				var awdVersionMinor:uint=byteData.readUnsignedByte();//_version[1] 			
				
				var flags:uint = byteData.readUnsignedShort(); // Parse bit flags 
				//_streaming = bitFlags.test(flags, bitFlags.FLAG1);//streaming is disabled for now, because it is not used in the parsersystem anyway
				if ((awdVersionMajor == 2) && (awdVersionMinor == 1)){
					if (testBitflag(flags, 2))//flag 2
						_document.globalOptions.matrixStorage="Precision";
					if (testBitflag(flags, 4))//flag 3
						_document.globalOptions.geometryStorage="Precision";
					if (testBitflag(flags, 8))//flag 4
						_document.globalOptions.propertyStorage ="Precision";
					if (testBitflag(flags, 16))//flag 5
						_document.globalOptions.attributesStorage ="Precision";
					if (!testBitflag(flags, 32))//flag 6
						_document.globalOptions.includeNormal=false;
					if (!testBitflag(flags, 64))//flag 7
						_document.globalOptions.includeTangent=false;
					if (!testBitflag(flags, 128))//flag 7
						_document.globalOptions.embedTextures=false;
				}
				var _compression:uint = byteData.readUnsignedByte(); // Get Compression
				var body_len:uint = byteData.readUnsignedInt();
				var _body:ByteArray;
				var _curPosition:uint=byteData.position;			
				switch (_compression)
				{
					case 0: 
						_document.globalOptions.compression="UNCOMPRESSED";
						_body = byteData;
						break;
					case 1: 
						_document.globalOptions.compression="DEFLATE";
						_body = new ByteArray();
						byteData.readBytes(_body, 0, byteData.bytesAvailable);
						_body.uncompress();
						break;
					case 2: 
						_document.globalOptions.compression="LZMA";
						_body = new ByteArray();
						byteData.readBytes(_body, 0, byteData.bytesAvailable);
						_body.uncompress("lzma");
						break;
				}
				_body.endian = Endian.LITTLE_ENDIAN;			
				var foundNameSpaceBlock:Boolean;
				var blockType:uint;
				var blockLength:uint;
				while ((_body.bytesAvailable>0) && (!foundNameSpaceBlock)){
					_body.position+=5; //id=4, ns=1,
					blockType=_body.readUnsignedByte();
					_body.position+=1; //flags=1;
					blockLength=_body.readUnsignedInt();
					if(blockType==254){
						foundNameSpaceBlock=true;					
						_body.position+=1; //ns-id
						var len:uint = _body.readUnsignedShort();
						_document.globalOptions.namespace = _body.readUTFBytes(len);
					}
					else{
						_body.position+=blockLength;
					}
				}				
			}
		}
		
		private function testBitflag(flags:uint, testFlag:uint):Boolean
		{
			return (flags & testFlag) == testFlag;
		}
		private function isGeometryInList( geometry:GeometryVO ):Boolean
		{
			for each ( var asset:AssetVO in _document.geometry )
			{
				if( asset.equals( geometry ) ) return true;
				
			}
			return false;
		}
		
		protected function documentReady( _document:DocumentVO ):void {
			throw new Error( "Abstract method error" );
		}
		
		protected function bitmapReady( bitmap:Bitmap ):void {
			throw new Error( "Abstract method error" );
		}
	}
}