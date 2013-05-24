package awaybuilder.controller.scene
{
	import awaybuilder.controller.events.DocumentModelEvent;
	import awaybuilder.controller.history.HistoryCommandBase;
	import awaybuilder.controller.history.HistoryEvent;
	import awaybuilder.controller.scene.events.SceneEvent;
	import awaybuilder.model.AssetsModel;
	import awaybuilder.model.DocumentModel;
	import awaybuilder.model.vo.ScenegraphItemVO;
	import awaybuilder.model.vo.scene.AssetVO;
	import awaybuilder.model.vo.scene.LightPickerVO;
	import awaybuilder.model.vo.scene.LightVO;
	import awaybuilder.view.components.controls.tree.DroppedItemVO;
	
	import flash.utils.Dictionary;
	
	import mx.collections.ArrayCollection;

	public class ReparentLightCommand extends HistoryCommandBase
	{
		[Inject]
		public var event:SceneEvent;
		
		[Inject]
		public var assets:AssetsModel;
		
		[Inject]
		public var document:DocumentModel;
		
		override public function execute():void
		{
			saveOldValue( event, event.newValue );
			
			var picker:LightPickerVO;
			
			for each( var item:DroppedItemVO in event.newValue ) 
			{
				var vo:ScenegraphItemVO = item.value as ScenegraphItemVO;
				
				if( vo.item is LightVO )
				{
					if( item.newParent == item.oldParent ) return;
					
					if( item.newParent )
					{
						picker = item.newParent.item as LightPickerVO;
						if( picker && !itemIsInList(picker.lights, vo.item as AssetVO) ) 
						{
							if( item.newPosition < picker.lights.length )
							{
								picker.lights.addItemAt( vo.item, item.newPosition );
							}
							else
							{
								picker.lights.addItem( vo.item );
							}
						}
					}
					
					if( item.oldParent )
					{ 
						picker = item.oldParent.item as LightPickerVO;
						if( picker && itemIsInList(picker.lights, vo.item as AssetVO) ) 
						{
							removeItem( picker.lights, vo.item as AssetVO );
						}
					}
				}
			}
			
			addToHistory( event );
			
			this.dispatch(new DocumentModelEvent(DocumentModelEvent.OBJECTS_UPDATED));
		}
		private function itemIsInList( collection:ArrayCollection, asset:AssetVO ):Boolean
		{
			for each( var a:AssetVO in collection )
			{
				if( a.equals( asset ) ) return true;
			}
			return false;
		}
		
		private function removeItem( source:ArrayCollection, oddItem:AssetVO ):void
		{
			for (var i:int = 0; i < source.length; i++) 
			{
				var item:AssetVO = source[i] as AssetVO;
				if( item.equals( oddItem ) )
				{
					source.removeItemAt( i );
					i--;
				}
			}
		}
		
		override protected function saveOldValue( event:HistoryEvent, prevValue:Object ):void 
		{
			if( !event.oldValue ) 
			{
				var oldValue:Dictionary = new Dictionary();
				for each( var item:DroppedItemVO in event.newValue ) 
				{
					var newItem:DroppedItemVO = new DroppedItemVO( item.value );
					newItem.newParent = item.oldParent;
					newItem.newPosition = item.newPosition;
					newItem.oldParent = item.newParent;
					newItem.oldPosition = item.oldPosition;
					oldValue[item.value] = newItem;
				}
				event.oldValue = oldValue;
			}
		}
		
	}
}