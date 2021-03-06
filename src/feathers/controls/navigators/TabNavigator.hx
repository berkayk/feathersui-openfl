/*
	Feathers UI
	Copyright 2020 Bowler Hat LLC. All Rights Reserved.

	This program is free software. You can redistribute and/or modify it in
	accordance with the terms of the accompanying license agreement.
 */

package feathers.controls.navigators;

import feathers.core.IDataSelector;
import feathers.core.IIndexSelector;
import feathers.core.InvalidationFlag;
import feathers.data.IFlatCollection;
import feathers.events.FeathersEvent;
import feathers.events.FlatCollectionEvent;
import feathers.layout.RelativePosition;
import feathers.themes.steel.components.SteelTabNavigatorStyles;
import openfl.display.DisplayObject;
import openfl.errors.ArgumentError;
import openfl.events.Event;

/**
	A container that supports navigation between views using a tab bar.

	The following example creates a tab navigator and adds some items:

	```hx
	var navigator = new TabNavigator();
	navigator.dataProvider = new ArrayCollection([
		TabItem.withClass("Home", HomeView),
		TabItem.withClass("Profile", ProfileView),
		TabItem.withClass("Settings", SettingsView)
	]);
	addChild(this.navigator);
	```

	@see [Tutorial: How to use the TabNavigator component](https://feathersui.com/learn/haxe-openfl/tab-navigator/)
	@see [Transitions for Feathers UI navigators](https://feathersui.com/learn/haxe-openfl/navigator-transitions/)
	@see `feathers.controls.navigators.TabItem`
	@see `feathers.controls.TabBar`

	@since 1.0.0
**/
@:access(feathers.controls.navigators.TabItem)
@:styleContext
class TabNavigator extends BaseNavigator implements IIndexSelector implements IDataSelector<TabItem> {
	/**
		Creates a new `TabNavigator` object.

		@since 1.0.0
	**/
	public function new() {
		initializeTabNavigatorTheme();

		super();
	}

	private var tabBar:TabBar;

	private var _dataProvider:IFlatCollection<TabItem> = null;

	@:flash.property
	public var dataProvider(get, set):IFlatCollection<TabItem>;

	private function get_dataProvider():IFlatCollection<TabItem> {
		return this._dataProvider;
	}

	private function set_dataProvider(value:IFlatCollection<TabItem>):IFlatCollection<TabItem> {
		if (this._dataProvider == value) {
			return this._dataProvider;
		}
		if (this._dataProvider != null) {
			this._dataProvider.removeEventListener(FlatCollectionEvent.ADD_ITEM, tabNavigator_dataProvider_addItemHandler);
			this._dataProvider.removeEventListener(FlatCollectionEvent.REMOVE_ITEM, tabNavigator_dataProvider_removeItemHandler);
			this._dataProvider.removeEventListener(FlatCollectionEvent.REPLACE_ITEM, tabNavigator_dataProvider_replaceItemHandler);
			this._dataProvider.removeEventListener(FlatCollectionEvent.REMOVE_ALL, tabNavigator_dataProvider_removeAllHandler);
			this._dataProvider.removeEventListener(FlatCollectionEvent.RESET, tabNavigator_dataProvider_resetHandler);
			for (item in this._dataProvider) {
				this.removeItemInternal(item.internalID);
			}
		}
		this._dataProvider = value;
		if (this._dataProvider != null) {
			for (item in this._dataProvider) {
				this.addItemInternal(item.internalID, item);
			}
			this._dataProvider.addEventListener(FlatCollectionEvent.ADD_ITEM, tabNavigator_dataProvider_addItemHandler, false, 0, true);
			this._dataProvider.addEventListener(FlatCollectionEvent.REMOVE_ITEM, tabNavigator_dataProvider_removeItemHandler, false, 0, true);
			this._dataProvider.addEventListener(FlatCollectionEvent.REPLACE_ITEM, tabNavigator_dataProvider_replaceItemHandler, false, 0, true);
			this._dataProvider.addEventListener(FlatCollectionEvent.REMOVE_ALL, tabNavigator_dataProvider_removeAllHandler, false, 0, true);
			this._dataProvider.addEventListener(FlatCollectionEvent.RESET, tabNavigator_dataProvider_resetHandler, false, 0, true);
		}
		this.setInvalid(DATA);
		if (this._dataProvider == null || this._dataProvider.length == 0) {
			// use the setter
			this.selectedIndex = -1;
		} else {
			// use the setter
			this.selectedIndex = 0;
		}
		return this._dataProvider;
	}

	private var _selectedIndex:Int = -1;

	/**
		@see `feathers.core.IIndexSelector.selectedIndex`
	**/
	@:flash.property
	public var selectedIndex(get, set):Int;

	private function get_selectedIndex():Int {
		return this._selectedIndex;
	}

	private function set_selectedIndex(value:Int):Int {
		if (this._dataProvider == null) {
			value = -1;
		}
		if (this._selectedIndex == value) {
			return this._selectedIndex;
		}
		this._selectedIndex = value;
		// using variable because if we were to call the selectedItem setter,
		// then this change wouldn't be saved properly
		if (this._selectedIndex == -1) {
			this._selectedItem = null;
		} else {
			this._selectedItem = this._dataProvider.get(this._selectedIndex);
		}
		this.setInvalid(SELECTION);
		FeathersEvent.dispatch(this, Event.CHANGE);
		return this._selectedIndex;
	}

	/**
		@see `feathers.core.IIndexSelector.maxSelectedIndex`
	**/
	@:flash.property
	public var maxSelectedIndex(get, never):Int;

	private function get_maxSelectedIndex():Int {
		if (this._dataProvider == null) {
			return -1;
		}
		return this._dataProvider.length - 1;
	}

	private var _selectedItem:TabItem = null;

	/**
		@see `feathers.core.IDataSelector.selectedItem`
	**/
	@:flash.property
	public var selectedItem(get, set):#if flash Dynamic #else TabItem #end;

	private function get_selectedItem():#if flash Dynamic #else TabItem #end {
		return this._selectedItem;
	}

	private function set_selectedItem(value:#if flash Dynamic #else TabItem #end):#if flash Dynamic #else TabItem #end {
		if (this._dataProvider == null) {
			// use the setter
			this.selectedIndex = -1;
			return this._selectedItem;
		}
		// use the setter
		this.selectedIndex = this._dataProvider.indexOf(value);
		return this._selectedItem;
	}

	/**
		The position of the navigator's tab bar.

		@since 1.0.0
	**/
	@:style
	public var tabBarPosition:RelativePosition = BOTTOM;

	private var _ignoreSelectionChange = false;

	override private function initialize():Void {
		super.initialize();

		if (this.tabBar == null) {
			this.tabBar = new TabBar();
			this.addChild(this.tabBar);
		}
		this.tabBar.addEventListener(Event.CHANGE, tabNavigator_tabBar_changeHandler);
	}

	private function itemToText(item:TabItem):String {
		return item.text;
	}

	private function initializeTabNavigatorTheme():Void {
		SteelTabNavigatorStyles.initialize();
	}

	override private function update():Void {
		var dataInvalid = this.isInvalid(DATA);
		var selectionInvalid = this.isInvalid(SELECTION);

		if (dataInvalid) {
			this.tabBar.itemToText = this.itemToText;
			this.tabBar.dataProvider = this._dataProvider;
		}

		if (selectionInvalid) {
			var oldIgnoreSelectionChange = this._ignoreSelectionChange;
			this._ignoreSelectionChange = true;
			this.tabBar.selectedIndex = this._selectedIndex;
			this._ignoreSelectionChange = oldIgnoreSelectionChange;

			if (this._selectedItem == null && this.activeItemID != null) {
				this.clearActiveItemInternal();
			}
			if (this._selectedItem != null && this.activeItemID != this._selectedItem.internalID) {
				this.showItemInternal(this._selectedItem.internalID, null);
			}
		}

		super.update();
	}

	override private function measure():Bool {
		var needsWidth = this.explicitWidth == null;
		var needsHeight = this.explicitHeight == null;
		var needsMinWidth = this.explicitMinWidth == null;
		var needsMinHeight = this.explicitMinHeight == null;
		var needsMaxWidth = this.explicitMaxWidth == null;
		var needsMaxHeight = this.explicitMaxHeight == null;
		if (!needsWidth && !needsHeight && !needsMinWidth && !needsMinHeight && !needsMaxWidth && !needsMaxHeight) {
			return false;
		}

		var needsToMeasureContent = this._autoSizeMode == CONTENT || this.stage == null;

		if (needsToMeasureContent) {
			if (this.explicitWidth != null) {
				this.tabBar.width = this.explicitWidth;
			} else {
				this.tabBar.resetWidth();
			}
			this.tabBar.validateNow();
			switch (this.tabBarPosition) {
				case TOP:
					this.topContentOffset = this.tabBar.height;
				case BOTTOM:
					this.bottomContentOffset = this.tabBar.height;
				default:
					throw new ArgumentError('Invalid tabBarPosition ${this.tabBarPosition}');
			}
		}
		return super.measure();
	}

	override private function layoutContent():Void {
		this.tabBar.x = 0.0;
		this.tabBar.width = this.actualWidth;
		this.tabBar.validateNow();
		switch (this.tabBarPosition) {
			case TOP:
				this.tabBar.y = 0.0;
			case BOTTOM:
				this.tabBar.y = this.actualHeight - this.tabBar.height;
			default:
				throw new ArgumentError('Invalid tabBarPosition ${this.tabBarPosition}');
		}

		if (this.activeItemView != null) {
			this.activeItemView.x = 0.0;
			switch (this.tabBarPosition) {
				case TOP:
					this.activeItemView.y = this.tabBar.height;
				case BOTTOM:
					this.activeItemView.y = 0.0;
				default:
					throw new ArgumentError('Invalid tabBarPosition ${this.tabBarPosition}');
			}
			this.activeItemView.width = this.actualWidth;
			this.activeItemView.height = this.actualHeight - this.tabBar.height;
		}
	}

	override private function getView(id:String):DisplayObject {
		var item = cast(this._addedItems.get(id), TabItem);
		return item.getView(this);
	}

	override private function disposeView(id:String, view:DisplayObject):Void {
		var item = cast(this._addedItems.get(id), TabItem);
		item.returnView(view);
	}

	private function tabNavigator_tabBar_changeHandler(event:Event):Void {
		if (this._ignoreSelectionChange) {
			return;
		}
		// use the setter
		this.selectedIndex = this.tabBar.selectedIndex;
	}

	private function tabNavigator_dataProvider_addItemHandler(event:FlatCollectionEvent):Void {
		var item = cast(event.addedItem, TabItem);
		this.addItemInternal(item.internalID, item);

		if (this._selectedIndex >= event.index) {
			// use the setter
			this.selectedIndex++;
		} else if (this._selectedIndex == -1) {
			// if the data provider was previously empty, automatically select
			// the new item

			// use the setter
			this.selectedIndex = 0;
		}
	}

	private function tabNavigator_dataProvider_removeItemHandler(event:FlatCollectionEvent):Void {
		var item = cast(event.removedItem, TabItem);
		this.removeItemInternal(item.internalID);

		if (this._dataProvider.length == 0) {
			// use the setter
			this.selectedIndex = -1;
		} else if (this._selectedIndex >= event.index) {
			// use the setter
			this.selectedIndex--;
		}
	}

	private function tabNavigator_dataProvider_replaceItemHandler(event:FlatCollectionEvent):Void {
		var addedItem = cast(event.addedItem, TabItem);
		var removedItem = cast(event.removedItem, TabItem);
		this.removeItemInternal(removedItem.internalID);
		this.addItemInternal(addedItem.internalID, addedItem);

		if (this._selectedIndex == event.index) {
			this.selectedItem = this._dataProvider.get(this._selectedIndex);
		}
	}

	private function tabNavigator_dataProvider_removeAllHandler(event:FlatCollectionEvent):Void {
		// use the setter
		this.selectedIndex = -1;
	}

	private function tabNavigator_dataProvider_resetHandler(event:FlatCollectionEvent):Void {
		// use the setter
		this.selectedIndex = -1;
	}
}
