/*
	Feathers UI
	Copyright 2020 Bowler Hat LLC. All Rights Reserved.

	This program is free software. You can redistribute and/or modify it in
	accordance with the terms of the accompanying license agreement.
 */

package feathers.controls;

import feathers.core.IUIControl;
import openfl.errors.ArgumentError;
import feathers.layout.ILayoutIndexObject;
import feathers.events.TreeViewEvent;
import feathers.controls.dataRenderers.IDataRenderer;
import feathers.controls.dataRenderers.ITreeViewItemRenderer;
import feathers.controls.dataRenderers.TreeViewItemRenderer;
import feathers.controls.supportClasses.AdvancedLayoutViewPort;
import feathers.controls.supportClasses.BaseScrollContainer;
import feathers.core.IDataSelector;
import feathers.core.IOpenCloseToggle;
import feathers.core.ITextControl;
import feathers.core.InvalidationFlag;
import feathers.data.IHierarchicalCollection;
import feathers.data.TreeViewItemState;
import feathers.events.FeathersEvent;
import feathers.events.HierarchicalCollectionEvent;
import feathers.layout.Direction;
import feathers.layout.ILayout;
import feathers.layout.IScrollLayout;
import feathers.layout.IVirtualLayout;
import feathers.themes.steel.components.SteelTreeViewStyles;
import feathers.utils.DisplayObjectRecycler;
import haxe.ds.ObjectMap;
import openfl.display.DisplayObject;
import openfl.errors.IllegalOperationError;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
import openfl.ui.Keyboard;
#if air
import openfl.ui.Multitouch;
#end

/**
	Displays a hierarchical tree of items. Supports scrolling, custom item
	renderers, and custom layouts.

	The following example creates a tree, gives it a data provider, tells
	the item renderer how to interpret the data, and listens for when the
	selection changes:

	```hx
	var treeView = new TreeView();

	treeView.dataProvider = new TreeCollection([
		new TreeNode({text: "Node 1"}, [
			new TreeNode({text: "Node 1A"}, [
				new TreeNode({text: "Node 1A-I"}),
				new TreeNode({text: "Node 1A-II"}),
				new TreeNode({text: "Node 1A-III"}),
				new TreeNode({text: "Node 1A-IV"})
			]),
			new TreeNode({text: "Node 1B"}),
			new TreeNode({text: "Node 1C"})
		]),
		new TreeNode({text: "Node 2"}, [
			new TreeNode({text: "Node 2A"}),
			new TreeNode({text: "Node 2B"}),
			new TreeNode({text: "Node 2C"})
		]),
		new TreeNode({text: "Node 3"}),
		new TreeNode({text: "Node 4"}, [
			new TreeNode({text: "Node 4A"}),
			new TreeNode({text: "Node 4B"}),
			new TreeNode({text: "Node 4C"}),
			new TreeNode({text: "Node 4D"}),
			new TreeNode({text: "Node 4E"})
		])
	]);

	treeView.itemToText = (item:TreeNode<Dynamic>) -> {
		return item.data.text;
	};

	treeView.addEventListener(Event.CHANGE, (event:Event) -> {
		var treeView = cast(event.currentTarget, TreeView);
		trace("TreeView changed: " + treeView.selectedLocation + " " + treeView.selectedItem.text);
	});

	this.addChild(treeView);
	```

	@see [Tutorial: How to use the TreeView component](https://feathersui.com/learn/haxe-openfl/tree-view/)

	@since 1.0.0
**/
@:access(feathers.data.TreeViewItemState)
@defaultXmlProperty("dataProvider")
@:styleContext
class TreeView extends BaseScrollContainer implements IDataSelector<Dynamic> {
	/**
		A variant used to style the tree view without a border. The variant is
		used by default on mobile.

		The following example uses this variant:

		```hx
		var treeView = new TreeView();
		treeView.variant = TreeView.VARIANT_BORDERLESS;
		```

		@see [Feathers UI User Manual: Themes](https://feathersui.com/learn/haxe-openfl/themes/)

		@since 1.0.0
	**/
	public static final VARIANT_BORDERLESS = "borderless";

	/**
		A variant used to style the tree view with a border. This variant is
		used by default on desktop.

		The following example uses this variant:

		```hx
		var treeView = new TreeView();
		treeView.variant = TreeView.VARIANT_BORDER;
		```

		@see [Feathers UI User Manual: Themes](https://feathersui.com/learn/haxe-openfl/themes/)

		@since 1.0.0
	**/
	public static final VARIANT_BORDER = "border";

	private static final INVALIDATION_FLAG_ITEM_RENDERER_FACTORY = InvalidationFlag.CUSTOM("itemRendererFactory");

	private static function defaultUpdateItemRenderer(itemRenderer:DisplayObject, state:TreeViewItemState):Void {
		if (Std.is(itemRenderer, ITextControl)) {
			var textControl = cast(itemRenderer, ITextControl);
			textControl.text = state.text;
		}
	}

	private static function defaultResetItemRenderer(itemRenderer:DisplayObject, state:TreeViewItemState):Void {
		if (Std.is(itemRenderer, ITextControl)) {
			var textControl = cast(itemRenderer, ITextControl);
			textControl.text = null;
		}
	}

	/**
		Creates a new `TreeView` object.

		@since 1.0.0
	**/
	public function new() {
		initializeTreeViewTheme();

		super();

		this.tabEnabled = true;
		this.focusRect = null;

		if (this.viewPort == null) {
			this.treeViewPort = new AdvancedLayoutViewPort();
			this.addChild(this.treeViewPort);
			this.viewPort = this.treeViewPort;
		}
	}

	private var treeViewPort:AdvancedLayoutViewPort;

	override private function get_focusEnabled():Bool {
		return (this._selectable || this.maxScrollY != this.minScrollY || this.maxScrollX != this.minScrollX)
			&& this._enabled
			&& this._focusEnabled;
	}

	private var openBranches:Array<Dynamic> = [];

	private var _dataProvider:IHierarchicalCollection<Dynamic> = null;

	/**
		The collection of data displayed by the tree view.

		The following example passes in a data provider and tells the item
		renderer how to interpret the data:

		```hx
		treeView.dataProvider = new TreeCollection([
			new TreeNode({text: "Node 1"}, [
				new TreeNode({text: "Node 1A"}, [
					new TreeNode({text: "Node 1A-I"}),
					new TreeNode({text: "Node 1A-II"}),
					new TreeNode({text: "Node 1A-III"}),
					new TreeNode({text: "Node 1A-IV"})
				]),
				new TreeNode({text: "Node 1B"}),
				new TreeNode({text: "Node 1C"})
			]),
			new TreeNode({text: "Node 2"}, [
				new TreeNode({text: "Node 2A"}),
				new TreeNode({text: "Node 2B"}),
				new TreeNode({text: "Node 2C"})
			]),
			new TreeNode({text: "Node 3"}),
			new TreeNode({text: "Node 4"}, [
				new TreeNode({text: "Node 4A"}),
				new TreeNode({text: "Node 4B"}),
				new TreeNode({text: "Node 4C"}),
				new TreeNode({text: "Node 4D"}),
				new TreeNode({text: "Node 4E"})
			])
		]);

		treeView.itemToText = (item:Dynamic) -> {
			return item.text;
		};
		```

		@default null

		@since 1.0.0
	**/
	@:flash.property
	public var dataProvider(get, set):IHierarchicalCollection<Dynamic>;

	private function get_dataProvider():IHierarchicalCollection<Dynamic> {
		return this._dataProvider;
	}

	private function set_dataProvider(value:IHierarchicalCollection<Dynamic>):IHierarchicalCollection<Dynamic> {
		if (this._dataProvider == value) {
			return this._dataProvider;
		}
		this._virtualCache.resize(0);
		if (this._dataProvider != null) {
			this._dataProvider.removeEventListener(Event.CHANGE, treeView_dataProvider_changeHandler);
			this._dataProvider.removeEventListener(HierarchicalCollectionEvent.ADD_ITEM, treeView_dataProvider_addItemHandler);
			this._dataProvider.removeEventListener(HierarchicalCollectionEvent.REMOVE_ITEM, treeView_dataProvider_removeItemHandler);
			this._dataProvider.removeEventListener(HierarchicalCollectionEvent.REPLACE_ITEM, treeView_dataProvider_replaceItemHandler);
			this._dataProvider.removeEventListener(HierarchicalCollectionEvent.REMOVE_ALL, treeView_dataProvider_removeAllHandler);
			this._dataProvider.removeEventListener(HierarchicalCollectionEvent.RESET, treeView_dataProvider_resetHandler);
			this._dataProvider.removeEventListener(HierarchicalCollectionEvent.UPDATE_ITEM, treeView_dataProvider_updateItemHandler);
			this._dataProvider.removeEventListener(HierarchicalCollectionEvent.UPDATE_ALL, treeView_dataProvider_updateAllHandler);
		}
		this._dataProvider = value;
		if (this._dataProvider != null) {
			var newSize = this.calculateTotalLayoutCount([]);
			this._virtualCache.resize(newSize);
			this._dataProvider.addEventListener(Event.CHANGE, treeView_dataProvider_changeHandler);
			this._dataProvider.addEventListener(HierarchicalCollectionEvent.ADD_ITEM, treeView_dataProvider_addItemHandler);
			this._dataProvider.addEventListener(HierarchicalCollectionEvent.REMOVE_ITEM, treeView_dataProvider_removeItemHandler);
			this._dataProvider.addEventListener(HierarchicalCollectionEvent.REPLACE_ITEM, treeView_dataProvider_replaceItemHandler);
			this._dataProvider.addEventListener(HierarchicalCollectionEvent.REMOVE_ALL, treeView_dataProvider_removeAllHandler);
			this._dataProvider.addEventListener(HierarchicalCollectionEvent.RESET, treeView_dataProvider_resetHandler);
			this._dataProvider.addEventListener(HierarchicalCollectionEvent.UPDATE_ITEM, treeView_dataProvider_updateItemHandler);
			this._dataProvider.addEventListener(HierarchicalCollectionEvent.UPDATE_ALL, treeView_dataProvider_updateAllHandler);
		}

		// reset the scroll position because this is a drastic change and
		// the data is probably completely different
		this.scrollX = 0.0;
		this.scrollY = 0.0;

		// clear the selection for the same reason
		this.selectedLocation = null;

		this.setInvalid(DATA);
		return this._dataProvider;
	}

	private var _selectedLocation:Array<Int> = null;

	/**
		The currently selected location. Returns `null` if no location is
		selected.

		The following example selects a specific location:

		```hx
		treeView.selectedLocation = [2, 0];
		```

		The following example clears the currently selected location:

		```hx
		treeView.selectedLocation = null;
		```

		The following example listens for when the selection changes, and it
		prints the new selected location to the debug console:

		```hx
		var treeView = new TreeView();
		function changeHandler(event:Event):Void
		{
			var treeView = cast(event.currentTarget, TreeView);
			trace("selection change: " + treeView.selectedLocation);
		}
		treeView.addEventListener(Event.CHANGE, changeHandler);
		```

		@default null

		@since 1.0.0
	**/
	@:flash.property
	public var selectedLocation(get, set):Array<Int>;

	private function get_selectedLocation():Array<Int> {
		return this._selectedLocation;
	}

	private function set_selectedLocation(value:Array<Int>):Array<Int> {
		if (!this._selectable || this._dataProvider == null) {
			value = null;
		}
		if (this._selectedLocation == value || this.compareLocations(this._selectedLocation, value) == 0) {
			return this._selectedLocation;
		}
		this._selectedLocation = value;
		// using variable because if we were to call the selectedItem setter,
		// then this change wouldn't be saved properly
		if (this._selectedLocation == null) {
			this._selectedItem = null;
		} else {
			this._selectedItem = this._dataProvider.get(this._selectedLocation);
		}
		this.setInvalid(SELECTION);
		FeathersEvent.dispatch(this, Event.CHANGE);
		return this._selectedLocation;
	}

	private var _selectedItem:Dynamic = null;

	/**
		@see `feathers.core.IDataSelector.selectedItem`
	**/
	@:flash.property
	public var selectedItem(get, set):Dynamic;

	private function get_selectedItem():Dynamic {
		return this._selectedItem;
	}

	private function set_selectedItem(value:Dynamic):Dynamic {
		if (!this._selectable || this._dataProvider == null) {
			// use the setter
			this.selectedLocation = null;
			return this._selectedItem;
		}
		// use the setter
		this.selectedLocation = this._dataProvider.locationOf(value);
		return this._selectedItem;
	}

	private var _previousLayout:ILayout;

	/**
		The layout algorithm used to position and size the tree view's items.

		By default, if no layout is provided by the time that the tree view
		initializes, a default layout that displays items vertically will be
		created.

		The following example tells the tree view to use a horizontal layout:

		```hx
		var layout = new HorizontalListLayout();
		layout.gap = 20.0;
		layout.padding = 20.0;
		treeView.layout = layout;
		```

		@since 1.0.0
	**/
	@:style
	public var layout:ILayout = null;

	private var _oldItemRendererRecycler:DisplayObjectRecycler<Dynamic, TreeViewItemState, DisplayObject> = null;

	private var _itemRendererRecycler:DisplayObjectRecycler<Dynamic, TreeViewItemState, DisplayObject> = DisplayObjectRecycler.withClass(TreeViewItemRenderer);

	/**
		Manages item renderers used by the tree view.

		In the following example, the tree view uses a custom item renderer
		class:

		```hx
		treeView.itemRendererRecycler = DisplayObjectRecycler.withClass(CustomItemRenderer);
		```

		@since 1.0.0
	**/
	@:flash.property
	public var itemRendererRecycler(get, set):DisplayObjectRecycler<Dynamic, TreeViewItemState, DisplayObject>;

	private function get_itemRendererRecycler():DisplayObjectRecycler<Dynamic, TreeViewItemState, DisplayObject> {
		return this._itemRendererRecycler;
	}

	private function set_itemRendererRecycler(value:DisplayObjectRecycler<Dynamic, TreeViewItemState, DisplayObject>):DisplayObjectRecycler<Dynamic,
		TreeViewItemState, DisplayObject> {
		if (this._itemRendererRecycler == value) {
			return this._itemRendererRecycler;
		}
		this._oldItemRendererRecycler = this._itemRendererRecycler;
		this._itemRendererRecycler = value;
		this.setInvalid(INVALIDATION_FLAG_ITEM_RENDERER_FACTORY);
		return this._itemRendererRecycler;
	}

	private var inactiveItemRenderers:Array<DisplayObject> = [];
	private var activeItemRenderers:Array<DisplayObject> = [];
	private var dataToItemRenderer = new ObjectMap<Dynamic, DisplayObject>();
	private var dataToLayoutIndex = new ObjectMap<Dynamic, Int>();
	private var itemRendererToData = new ObjectMap<DisplayObject, Dynamic>();
	private var _unrenderedLocations:Array<Array<Int>> = [];
	private var _unrenderedLayoutIndices:Array<Int> = [];
	private var _virtualCache:Array<Dynamic> = [];

	private var _selectable:Bool = true;

	/**
		Determines if items in the tree view may be selected. By default only a
		single item may be selected at any given time. In other words, if item
		_A_ is already selected, and the user selects item _B_, item _A_ will be
		deselected automatically.

		The following example disables selection of items in the tree view:

		```hx
		treeView.selectable = false;
		```

		@default true

		@see `TreeView.selectedItem`
		@see `TreeView.selectedIndex`
	**/
	@:flash.property
	public var selectable(get, set):Bool;

	private function get_selectable():Bool {
		return this._selectable;
	}

	private function set_selectable(value:Bool):Bool {
		if (this._selectable == value) {
			return this._selectable;
		}
		this._selectable = value;
		if (!this._selectable) {
			// use the setter
			this.selectedLocation = null;
		}
		return this._selectable;
	}

	private var _virtualLayout:Bool = true;

	/**
		Indicates if the tree view's layout is allowed to virtualize items or
		not.

		The following example disables virtual layouts:

		```hx
		treeView.virtualLayout = false;
		```

		@since 1.0.0
	**/
	@:flash.property
	public var virtualLayout(get, set):Bool;

	private function get_virtualLayout():Bool {
		return this._virtualLayout;
	}

	private function set_virtualLayout(value:Bool):Bool {
		if (this._virtualLayout = value) {
			return this._virtualLayout;
		}
		this._virtualLayout = value;
		this.setInvalid(LAYOUT);
		return this._virtualLayout;
	}

	/**
		Indicates if selection is changed with `MouseEvent.CLICK` or
		`TouchEvent.TOUCH_TAP` when the item renderer does not implement the
		`IToggle` interface. If set to `false`, all item renderers must control
		their own selection manually (not only ones that implement `IToggle`).

		The following example disables pointer selection:

		```hx
		treeView.pointerSelectionEnabled = false;
		```

		@since 1.0.0
	**/
	public var pointerSelectionEnabled:Bool = true;

	private var _ignoreSelectionChange = false;
	private var _ignoreOpenedChange = false;

	/**
		Converts an item to text to display within tree view. By default, the
		`toString()` method is called to convert an item to text. This method
		may be replaced to provide custom text.

		For example, consider the following item:

		```hx
		{ text: "Example Item" }
		```

		If the `TreeView` should display the text "Example Item", a custom
		implementation of `itemToText()` might look like this:

		```hx
		treeView.itemToText = (item:Dynamic) -> {
			return item.text;
		};
		```

		@since 1.0.0
	**/
	public dynamic function itemToText(data:Dynamic):String {
		return Std.string(data);
	}

	/**
		Indicates if a branch is currently opened or closed. If the object is
		not a branch, or does not exist in the data provider, returns `false`.

		@since 1.0.0
	**/
	public function isBranchOpen(branch:Dynamic):Bool {
		if (this._dataProvider == null || !this._dataProvider.contains(branch)) {
			return false;
		}
		return this._dataProvider.isBranch(branch) && this.openBranches.indexOf(branch) != -1;
	}

	/**
		Opens or closes a branch.

		@since 1.0.0
	**/
	public function toggleBranch(branch:Dynamic, open:Bool):Void {
		if (this._dataProvider == null || !this._dataProvider.contains(branch)) {
			throw new ArgumentError("Cannot open branch because it is not in the data provider.");
		}
		if (!this._dataProvider.isBranch(branch)) {
			throw new ArgumentError("Cannot open item because it is not a branch.");
		}
		var alreadyOpen = this.openBranches.indexOf(branch) != -1;
		if ((open && alreadyOpen) || (!open && !alreadyOpen)) {
			// nothing to change
			return;
		}
		if (open) {
			this.openBranches.push(branch);
			var layoutIndex = this.dataToLayoutIndex.get(branch);
			var location = this._dataProvider.locationOf(branch);
			insertChildrenIntoVirtualCache(location, layoutIndex);
			FeathersEvent.dispatch(this, Event.OPEN);
		} else {
			this.openBranches.remove(branch);
			var layoutIndex = this.dataToLayoutIndex.get(branch);
			var location = this._dataProvider.locationOf(branch);
			removeChildrenFromVirtualCache(location, layoutIndex);
			FeathersEvent.dispatch(this, Event.CLOSE);
		}
		this.setInvalid(DATA);
	}

	/**
		Returns the current item renderer used to render a specific item from
		the data provider. May return `null` if an item doesn't currently have
		an item renderer.

		**Note:** Most tree views use "virtual" layouts, which means that only
		the currently-visible subset of items will have an item renderer. As the
		tree view scrolls, the items with item renderers will change, and item
		renderers may even be re-used to display different items.

		@since 1.0.0
	**/
	public function itemToItemRenderer(item:Dynamic):DisplayObject {
		return this.dataToItemRenderer.get(item);
	}

	/**
		Returns the current item from the data provider that is rendered by a
		specific item renderer.

		@since 1.0.0
	**/
	public function itemRendererToItem(itemRenderer:DisplayObject):Dynamic {
		return this.itemRendererToData.get(itemRenderer);
	}

	/**
		Scrolls the list view so that the specified item renderer is completely
		visible. If the item renderer is already completely visible, does not
		update the scroll position.

		A custom animation duration may be specified. To update the scroll
		position without animation, pass a value of `0.0` for the duration.

		 @since 1.0.0
	**/
	public function scrollToLocation(location:Array<Int>, ?animationDuration:Float):Void {
		if (this._dataProvider == null || this._dataProvider.getLength() == 0) {
			return;
		}

		var targetX = this.scrollX;
		var targetY = this.scrollY;
		if (Std.is(this.layout, IScrollLayout)) {
			var displayIndex = this.locationToDisplayIndex(location, true);
			var scrollLayout = cast(this.layout, IScrollLayout);
			var result = scrollLayout.getNearestScrollPositionForIndex(displayIndex, this._layoutItems.length, this.viewPort.visibleWidth,
				this.viewPort.visibleHeight);
			targetX = result.x;
			targetY = result.y;
		} else {
			var item = this._dataProvider.get(location);
			var itemRenderer = this.dataToItemRenderer.get(item);
			if (itemRenderer == null) {
				return;
			}

			var maxX = itemRenderer.x;
			var minX = maxX + itemRenderer.width - this.viewPort.visibleWidth;
			if (targetX < minX) {
				targetX = minX;
			} else if (targetX > maxX) {
				targetX = maxX;
			}

			var maxY = itemRenderer.y;
			var minY = maxY + itemRenderer.height - this.viewPort.visibleHeight;
			if (targetY < minY) {
				targetY = minY;
			} else if (targetY > maxY) {
				targetY = maxY;
			}
		}
		this.scroller.scrollX = targetX;
		this.scroller.scrollY = targetY;
	}

	private function initializeTreeViewTheme():Void {
		SteelTreeViewStyles.initialize();
	}

	private var _layoutItems:Array<DisplayObject> = [];

	override private function update():Void {
		var layoutInvalid = this.isInvalid(LAYOUT);
		var stylesInvalid = this.isInvalid(STYLES);

		if (layoutInvalid || stylesInvalid) {
			if (this._previousLayout != this.layout) {
				this._layoutItems.resize(0);
				var newSize = this.calculateTotalLayoutCount([]);
				this._layoutItems.resize(newSize);
			}
			this.treeViewPort.layout = this.layout;
			this._previousLayout = this.layout;
		}

		this.treeViewPort.refreshChildren = this.refreshItemRenderers;

		for (flag in this._invalidationFlags.keys()) {
			this.treeViewPort.setInvalid(flag);
		}

		super.update();
	}

	override private function refreshScrollerValues():Void {
		super.refreshScrollerValues();
		if (Std.is(this.layout, IScrollLayout)) {
			var scrollLayout = cast(this.layout, IScrollLayout);
			this.scroller.forceElasticTop = scrollLayout.elasticTop;
			this.scroller.forceElasticRight = scrollLayout.elasticRight;
			this.scroller.forceElasticBottom = scrollLayout.elasticBottom;
			this.scroller.forceElasticLeft = scrollLayout.elasticLeft;
		} else {
			this.scroller.forceElasticTop = false;
			this.scroller.forceElasticRight = false;
			this.scroller.forceElasticBottom = false;
			this.scroller.forceElasticLeft = false;
		}
	}

	private function refreshItemRenderers(items:Array<DisplayObject>):Void {
		this._layoutItems = items;

		if (this._itemRendererRecycler.update == null) {
			this._itemRendererRecycler.update = defaultUpdateItemRenderer;
			if (this._itemRendererRecycler.reset == null) {
				this._itemRendererRecycler.reset = defaultResetItemRenderer;
			}
		}

		var itemRendererInvalid = this.isInvalid(INVALIDATION_FLAG_ITEM_RENDERER_FACTORY);
		this.refreshInactiveItemRenderers(itemRendererInvalid);
		this.findUnrenderedData();
		this.recoverInactiveItemRenderers(this._itemRendererRecycler);
		this.renderUnrenderedData();
		this.freeInactiveItemRenderers(this._itemRendererRecycler);
		if (this.inactiveItemRenderers.length > 0) {
			throw new IllegalOperationError(Type.getClassName(Type.getClass(this)) + ": inactive item renderers should be empty after updating.");
		}
	}

	private function refreshInactiveItemRenderers(factoryInvalid:Bool):Void {
		var temp = this.inactiveItemRenderers;
		this.inactiveItemRenderers = this.activeItemRenderers;
		this.activeItemRenderers = temp;
		if (this.activeItemRenderers.length > 0) {
			throw new IllegalOperationError(Type.getClassName(Type.getClass(this)) + ": active item renderers should be empty before updating.");
		}
		if (factoryInvalid) {
			this.recoverInactiveItemRenderers(this._oldItemRendererRecycler != null ? this._oldItemRendererRecycler : this._itemRendererRecycler);
			this.freeInactiveItemRenderers(this._oldItemRendererRecycler != null ? this._oldItemRendererRecycler : this._itemRendererRecycler);
			this._oldItemRendererRecycler = null;
		}
	}

	private function recoverInactiveItemRenderers(recycler:DisplayObjectRecycler<Dynamic, TreeViewItemState, DisplayObject>):Void {
		for (itemRenderer in this.inactiveItemRenderers) {
			if (itemRenderer == null) {
				continue;
			}
			var item = this.itemRendererToData.get(itemRenderer);
			if (item == null) {
				return;
			}
			this.itemRendererToData.remove(itemRenderer);
			this.dataToItemRenderer.remove(item);
			this.dataToLayoutIndex.remove(item);
			itemRenderer.removeEventListener(MouseEvent.CLICK, treeView_itemRenderer_clickHandler);
			itemRenderer.removeEventListener(TouchEvent.TOUCH_TAP, treeView_itemRenderer_touchTapHandler);
			if (Std.is(itemRenderer, IToggle)) {
				itemRenderer.removeEventListener(Event.CHANGE, treeView_itemRenderer_changeHandler);
			}
			if (Std.is(itemRenderer, IOpenCloseToggle)) {
				itemRenderer.removeEventListener(Event.OPEN, treeView_itemRenderer_openHandler);
				itemRenderer.removeEventListener(Event.CLOSE, treeView_itemRenderer_closeHandler);
			}
			this._currentItemState.owner = this;
			this._currentItemState.data = item;
			this._currentItemState.location = null;
			this._currentItemState.layoutIndex = -1;
			this._currentItemState.selected = false;
			this._currentItemState.enabled = true;
			this._currentItemState.text = null;
			this._currentItemState.branch = false;
			this._currentItemState.opened = false;
			var oldIgnoreSelectionChange = this._ignoreSelectionChange;
			this._ignoreSelectionChange = true;
			var oldIgnoreOpenedChange = this._ignoreOpenedChange;
			this._ignoreOpenedChange = true;
			if (recycler != null && recycler.reset != null) {
				recycler.reset(itemRenderer, this._currentItemState);
			}
			if (Std.is(itemRenderer, IUIControl)) {
				var uiControl = cast(itemRenderer, IUIControl);
				uiControl.enabled = this._currentItemState.enabled;
			}
			if (Std.is(itemRenderer, IToggle)) {
				var toggle = cast(itemRenderer, IToggle);
				toggle.selected = this._currentItemState.selected;
			}
			if (Std.is(itemRenderer, IOpenCloseToggle)) {
				var openCloseItem = cast(itemRenderer, IOpenCloseToggle);
				openCloseItem.opened = this._currentItemState.opened;
			}
			if (Std.is(itemRenderer, ITreeViewItemRenderer)) {
				var treeItem = cast(itemRenderer, ITreeViewItemRenderer);
				treeItem.branch = this._currentItemState.branch;
			}
			if (Std.is(itemRenderer, ILayoutIndexObject)) {
				var layoutIndexObject = cast(itemRenderer, ILayoutIndexObject);
				layoutIndexObject.layoutIndex = this._currentItemState.layoutIndex;
			}
			if (Std.is(itemRenderer, IDataRenderer)) {
				var dataRenderer = cast(itemRenderer, IDataRenderer);
				dataRenderer.data = this._currentItemState.data;
			}
			this._ignoreOpenedChange = oldIgnoreOpenedChange;
			this._ignoreSelectionChange = oldIgnoreSelectionChange;
		}
	}

	private function freeInactiveItemRenderers(recycler:DisplayObjectRecycler<Dynamic, TreeViewItemState, DisplayObject>):Void {
		for (itemRenderer in this.inactiveItemRenderers) {
			if (itemRenderer == null) {
				continue;
			}
			this.destroyItemRenderer(itemRenderer, recycler);
		}
		this.inactiveItemRenderers.resize(0);
	}

	private var _currentItemState = new TreeViewItemState();
	private var _visibleIndices:VirtualLayoutRange = new VirtualLayoutRange(0, 0);

	private function findUnrenderedData():Void {
		// remove all old items, then fill with null
		this._layoutItems.resize(0);
		var newSize = this.calculateTotalLayoutCount([]);
		this._layoutItems.resize(newSize);

		if (this._virtualLayout && Std.is(this.layout, IVirtualLayout)) {
			var virtualLayout = cast(this.layout, IVirtualLayout);
			virtualLayout.virtualCache = this._virtualCache;
			virtualLayout.getVisibleIndices(this._layoutItems.length, this.treeViewPort.visibleWidth, this.treeViewPort.visibleHeight, this._visibleIndices);
		} else {
			this._visibleIndices.start = 0;
			this._visibleIndices.end = this._layoutItems.length - 1;
		}
		this.findUnrenderedDataForLocation([], 0);
	}

	private function findUnrenderedDataForLocation(location:Array<Int>, layoutIndex:Int):Int {
		if (this._dataProvider == null) {
			return layoutIndex;
		}
		for (i in 0...this._dataProvider.getLength(location)) {
			location.push(i);
			var item = this._dataProvider.get(location);
			if (layoutIndex < this._visibleIndices.start || layoutIndex > this._visibleIndices.end) {
				this._layoutItems[layoutIndex] = null;
			} else {
				this.findItemRenderer(item, location.copy(), layoutIndex);
			}
			layoutIndex++;
			if (this._dataProvider.isBranch(item) && this.openBranches.indexOf(item) != -1) {
				layoutIndex = this.findUnrenderedDataForLocation(location, layoutIndex);
			}
			location.pop();
		}
		return layoutIndex;
	}

	private function findItemRenderer(item:Dynamic, location:Array<Int>, layoutIndex:Int):Void {
		var itemRenderer = this.dataToItemRenderer.get(item);
		if (itemRenderer == null) {
			this._unrenderedLocations.push(location);
			this._unrenderedLayoutIndices.push(layoutIndex);
			return;
		}
		this.refreshItemRendererProperties(itemRenderer, item, location, layoutIndex);
		// if this item renderer used to be the typical layout item, but
		// it isn't anymore, it may have been set invisible
		itemRenderer.visible = true;
		this._layoutItems[layoutIndex] = itemRenderer;
		var removed = this.inactiveItemRenderers.remove(itemRenderer);
		if (!removed) {
			throw new IllegalOperationError(Type.getClassName(Type.getClass(this))
				+ ": item renderer map contains bad data. This may be caused by duplicate items in the data provider, which is not allowed.");
		}
		this.activeItemRenderers.push(itemRenderer);
	}

	private function renderUnrenderedData():Void {
		for (location in this._unrenderedLocations) {
			var layoutIndex = this._unrenderedLayoutIndices.shift();
			var item = this._dataProvider.get(location);
			var itemRenderer = this.createItemRenderer(item, location, layoutIndex);
			itemRenderer.visible = true;
			this.activeItemRenderers.push(itemRenderer);
			this.treeViewPort.addChild(itemRenderer);
			this._layoutItems[layoutIndex] = itemRenderer;
		}
		this._unrenderedLocations.resize(0);
	}

	private function createItemRenderer(item:Dynamic, location:Array<Int>, layoutIndex:Int):DisplayObject {
		var itemRenderer:DisplayObject = null;
		if (this.inactiveItemRenderers.length == 0) {
			itemRenderer = this._itemRendererRecycler.create();
		} else {
			itemRenderer = this.inactiveItemRenderers.shift();
		}
		this.refreshItemRendererProperties(itemRenderer, item, location, layoutIndex);
		itemRenderer.addEventListener(MouseEvent.CLICK, treeView_itemRenderer_clickHandler);
		#if (openfl >= "9.0.0")
		itemRenderer.addEventListener(TouchEvent.TOUCH_TAP, treeView_itemRenderer_touchTapHandler);
		#end
		if (Std.is(itemRenderer, IToggle)) {
			itemRenderer.addEventListener(Event.CHANGE, treeView_itemRenderer_changeHandler);
		}
		if (Std.is(itemRenderer, IOpenCloseToggle)) {
			itemRenderer.addEventListener(Event.OPEN, treeView_itemRenderer_openHandler);
			itemRenderer.addEventListener(Event.CLOSE, treeView_itemRenderer_closeHandler);
		}
		this.itemRendererToData.set(itemRenderer, item);
		this.dataToItemRenderer.set(item, itemRenderer);
		this.dataToLayoutIndex.set(item, layoutIndex);
		return itemRenderer;
	}

	private function destroyItemRenderer(itemRenderer:DisplayObject, recycler:DisplayObjectRecycler<Dynamic, TreeViewItemState, DisplayObject>):Void {
		this.treeViewPort.removeChild(itemRenderer);
		if (recycler != null && recycler.destroy != null) {
			recycler.destroy(itemRenderer);
		}
	}

	private function populateCurrentItemState(item:Dynamic, location:Array<Int>, layoutIndex:Int):Void {
		this._currentItemState.owner = this;
		this._currentItemState.data = item;
		this._currentItemState.location = location;
		this._currentItemState.layoutIndex = layoutIndex;
		this._currentItemState.branch = this._dataProvider != null && this._dataProvider.isBranch(item);
		this._currentItemState.opened = this._currentItemState.branch && this.openBranches.indexOf(item) != -1;
		this._currentItemState.selected = item == this._selectedItem;
		this._currentItemState.enabled = this._enabled;
		this._currentItemState.text = itemToText(item);
	}

	private function refreshItemRendererProperties(itemRenderer:DisplayObject, item:Dynamic, location:Array<Int>, layoutIndex:Int):Void {
		this.populateCurrentItemState(item, location, layoutIndex);
		var oldIgnoreSelectionChange = this._ignoreSelectionChange;
		this._ignoreSelectionChange = true;
		var oldIgnoreOpenedChange = this._ignoreOpenedChange;
		this._ignoreOpenedChange = true;
		if (this._itemRendererRecycler.update != null) {
			this._itemRendererRecycler.update(itemRenderer, this._currentItemState);
		}
		if (Std.is(itemRenderer, IUIControl)) {
			var uiControl = cast(itemRenderer, IUIControl);
			uiControl.enabled = this._currentItemState.enabled;
		}
		if (Std.is(itemRenderer, IDataRenderer)) {
			var dataRenderer = cast(itemRenderer, IDataRenderer);
			// if the renderer is an IDataRenderer, this cannot be overridden
			dataRenderer.data = this._currentItemState.data;
		}
		if (Std.is(itemRenderer, IToggle)) {
			var toggle = cast(itemRenderer, IToggle);
			// if the renderer is an IToggle, this cannot be overridden
			toggle.selected = this._currentItemState.selected;
		}
		if (Std.is(itemRenderer, ITreeViewItemRenderer)) {
			var treeItem = cast(itemRenderer, ITreeViewItemRenderer);
			treeItem.location = this._currentItemState.location;
			treeItem.branch = this._currentItemState.branch;
		}
		if (Std.is(itemRenderer, ILayoutIndexObject)) {
			var layoutIndexObject = cast(itemRenderer, ILayoutIndexObject);
			layoutIndexObject.layoutIndex = this._currentItemState.layoutIndex;
		}
		if (Std.is(itemRenderer, IOpenCloseToggle)) {
			var openCloseItem = cast(itemRenderer, IOpenCloseToggle);
			openCloseItem.opened = this._currentItemState.opened;
		}
		this._ignoreOpenedChange = oldIgnoreOpenedChange;
		this._ignoreSelectionChange = oldIgnoreSelectionChange;
	}

	private function refreshSelectedLocationAfterFilterOrSort():Void {
		if (this._selectedLocation == null) {
			return;
		}
		// the location may have changed, possibily even to null, if the item
		// was filtered out
		this.selectedLocation = this._dataProvider.locationOf(this._selectedItem); // use the setter
	}

	private function dispatchItemTriggerEvent(data:Dynamic):Void {
		var location = this._dataProvider.locationOf(data);
		var layoutIndex = this.dataToLayoutIndex.get(data);
		this.populateCurrentItemState(data, location, layoutIndex);
		TreeViewEvent.dispatch(this, TreeViewEvent.ITEM_TRIGGER, this._currentItemState);
	}

	private function calculateTotalLayoutCount(location:Array<Int>):Int {
		if (this._dataProvider == null) {
			return 0;
		}
		var itemCount = this._dataProvider.getLength(location);
		var result = itemCount;
		for (i in 0...itemCount) {
			location.push(i);
			var item = this._dataProvider.get(location);
			if (this._dataProvider.isBranch(item) && this.openBranches.indexOf(item) != -1) {
				result += this.calculateTotalLayoutCount(location);
			}
			location.pop();
		}
		return result;
	}

	private function insertChildrenIntoVirtualCache(location:Array<Int>, layoutIndex:Int):Void {
		var length = this._dataProvider.getLength(location);
		for (i in 0...length) {
			location.push(i);
			layoutIndex++;
			this._virtualCache.insert(layoutIndex, null);
			var item = this._dataProvider.get(location);
			if (this._dataProvider.isBranch(item) && this.openBranches.indexOf(item) != -1) {
				insertChildrenIntoVirtualCache(location, layoutIndex);
			}
			location.pop();
		}
	}

	private function removeChildrenFromVirtualCache(location:Array<Int>, layoutIndex:Int):Void {
		var length = this._dataProvider.getLength(location);
		for (i in 0...length) {
			location.push(i);
			layoutIndex++;
			this._virtualCache.remove(layoutIndex);
			var item = this._dataProvider.get(location);
			if (this._dataProvider.isBranch(item) && this.openBranches.indexOf(item) != -1) {
				removeChildrenFromVirtualCache(location, layoutIndex);
			}
			location.pop();
		}
	}

	private function compareLocations(location1:Array<Int>, location2:Array<Int>):Int {
		var null1 = location1 == null;
		var null2 = location2 == null;
		if (null1 && null2) {
			return 0;
		} else if (null1) {
			return 1;
		} else if (null2) {
			return -1;
		}
		var length1 = location1.length;
		var length2 = location2.length;
		var min = length1;
		if (length2 < min) {
			min = length2;
		}
		for (i in 0...min) {
			var index1 = location1[i];
			var index2 = location2[i];
			if (index1 < index2) {
				return -1;
			}
			if (index1 > index2) {
				return 1;
			}
		}
		if (length1 < length2) {
			return -1;
		} else if (length1 > length2) {
			return 1;
		}
		return 0;
	}

	private var _currentDisplayIndex:Int;

	private function displayIndexToLocation(displayIndex:Int):Array<Int> {
		this._currentDisplayIndex = -1;
		return this.displayIndexToLocationAtBranch(displayIndex, []);
	}

	private function displayIndexToLocationAtBranch(target:Int, locationOfBranch:Array<Int>):Array<Int> {
		for (i in 0...this._dataProvider.getLength(locationOfBranch)) {
			this._currentDisplayIndex++;
			locationOfBranch[locationOfBranch.length] = i;
			if (this._currentDisplayIndex == target) {
				return locationOfBranch;
			}
			var child = this._dataProvider.get(locationOfBranch);
			if (this._dataProvider.isBranch(child)) {
				if (this.openBranches.indexOf(child) != -1) {
					var result = this.displayIndexToLocationAtBranch(target, locationOfBranch);
					if (result != null) {
						return result;
					}
				}
			}
			locationOfBranch.resize(locationOfBranch.length - 1);
		}
		return null;
	}

	private function locationToDisplayIndex(location:Array<Int>, returnNearestIfBranchNotOpen:Bool):Int {
		this._currentDisplayIndex = -1;
		return this.locationToDisplayIndexAtBranch([], location, returnNearestIfBranchNotOpen);
	}

	private function locationToDisplayIndexAtBranch(locationOfBranch:Array<Int>, locationToFind:Array<Int>, returnNearestIfBranchNotOpen:Bool):Int {
		for (i in 0...this._dataProvider.getLength(locationOfBranch)) {
			this._currentDisplayIndex++;
			locationOfBranch[locationOfBranch.length] = i;
			if (this.compareLocations(locationOfBranch, locationToFind) == 0) {
				return this._currentDisplayIndex;
			}
			var child = this._dataProvider.get(locationOfBranch);
			if (this._dataProvider.isBranch(child)) {
				if (this.openBranches.indexOf(child) != -1) {
					var result = this.locationToDisplayIndexAtBranch(locationOfBranch, locationToFind, returnNearestIfBranchNotOpen);
					if (result != -1) {
						return result;
					}
				} else if (returnNearestIfBranchNotOpen) {
					// if the location is inside a closed branch
					// return that branch
					return this._currentDisplayIndex;
				}
			}
			locationOfBranch.resize(locationOfBranch.length - 1);
		}
		// location was not found!
		return -1;
	}

	private function navigateWithKeyboard(event:KeyboardEvent):Void {
		if (this._layoutItems.length == 0) {
			return;
		}
		var startIndex = this.locationToDisplayIndex(this._selectedLocation, false);
		var result = startIndex;
		switch (event.keyCode) {
			case Keyboard.UP:
				result = result - 1;
			case Keyboard.DOWN:
				result = result + 1;
			case Keyboard.LEFT:
				result = result - 1;
			case Keyboard.RIGHT:
				result = result + 1;
			case Keyboard.PAGE_UP:
				result = result - 1;
			case Keyboard.PAGE_DOWN:
				result = result + 1;
			case Keyboard.HOME:
				result = 0;
			case Keyboard.END:
				result = this._layoutItems.length - 1;
			default:
				// not keyboard navigation
				return;
		}
		if (result < 0) {
			result = 0;
		} else if (result >= this._layoutItems.length) {
			result = this._layoutItems.length - 1;
		}
		event.stopPropagation();
		// use the setter
		this.selectedLocation = this.displayIndexToLocation(result);
		if (this._selectedLocation != null) {
			this.scrollToLocation(this._selectedLocation);
		}
	}

	override private function baseScrollContainer_keyDownHandler(event:KeyboardEvent):Void {
		if (!this._enabled || event.isDefaultPrevented()) {
			return;
		}

		if (event.keyCode == Keyboard.ENTER) {
			if (this._selectedItem != null) {
				this.dispatchItemTriggerEvent(this._selectedItem);
			}
		}

		if (this._selectedLocation != null && event.keyCode == Keyboard.SPACE) {
			event.stopPropagation();
			if (this._dataProvider.isBranch(this._selectedItem)) {
				this.toggleBranch(this._selectedItem, this.openBranches.indexOf(this._selectedItem) == -1);
			}
			return;
		}
		this.navigateWithKeyboard(event);
	}

	private function treeView_itemRenderer_touchTapHandler(event:TouchEvent):Void {
		if (!this._enabled) {
			return;
		}
		if (event.isPrimaryTouchPoint #if air && Multitouch.mapTouchToMouse #end) {
			// ignore the primary one because MouseEvent.CLICK will catch it
			return;
		}

		var itemRenderer = cast(event.currentTarget, DisplayObject);
		var data = this.itemRendererToData.get(itemRenderer);
		this.dispatchItemTriggerEvent(data);

		if (!this._selectable || !this.pointerSelectionEnabled) {
			return;
		}
		if (Std.is(itemRenderer, IToggle)) {
			// handled by Event.CHANGE listener instead
			return;
		}
		// use the setter
		this.selectedLocation = this._dataProvider.locationOf(data);
	}

	private function treeView_itemRenderer_clickHandler(event:MouseEvent):Void {
		if (!this._enabled) {
			return;
		}
		var itemRenderer = cast(event.currentTarget, DisplayObject);
		var data = this.itemRendererToData.get(itemRenderer);
		this.dispatchItemTriggerEvent(data);

		if (!this._selectable || !this.pointerSelectionEnabled) {
			return;
		}
		if (Std.is(itemRenderer, IToggle)) {
			// handled by Event.CHANGE listener instead
			return;
		}
		// use the setter
		this.selectedLocation = this._dataProvider.locationOf(data);
	}

	private function treeView_itemRenderer_changeHandler(event:Event):Void {
		if (this._ignoreSelectionChange) {
			return;
		}
		var itemRenderer = cast(event.currentTarget, DisplayObject);
		if (!this._selectable) {
			var toggle = cast(itemRenderer, IToggle);
			var oldIgnoreSelectionChange = this._ignoreSelectionChange;
			this._ignoreSelectionChange = true;
			toggle.selected = false;
			this._ignoreSelectionChange = oldIgnoreSelectionChange;
			return;
		}
		var item = this.itemRendererToData.get(itemRenderer);
		// use the setter
		this.selectedItem = item;
	}

	private function treeView_itemRenderer_openHandler(event:Event):Void {
		if (this._ignoreOpenedChange) {
			return;
		}
		var itemRenderer = cast(event.currentTarget, DisplayObject);
		var item = this.itemRendererToData.get(itemRenderer);
		this.toggleBranch(item, true);
	}

	private function treeView_itemRenderer_closeHandler(event:Event):Void {
		if (this._ignoreOpenedChange) {
			return;
		}
		var itemRenderer = cast(event.currentTarget, DisplayObject);
		var item = this.itemRendererToData.get(itemRenderer);
		this.toggleBranch(item, false);
	}

	private function treeView_dataProvider_changeHandler(event:Event):Void {
		if (this._virtualCache != null) {
			this._virtualCache.resize(0);
			var newSize = this.calculateTotalLayoutCount([]);
			this._virtualCache.resize(newSize);
		}
		this.setInvalid(DATA);
	}

	private function treeView_dataProvider_addItemHandler(event:HierarchicalCollectionEvent):Void {
		if (this._selectedLocation == null) {
			return;
		}
		if (this.compareLocations(this._selectedLocation, event.location) >= 0) {
			// use the setter
			this.selectedLocation = this._dataProvider.locationOf(this._selectedItem);
		}
	}

	private function treeView_dataProvider_removeItemHandler(event:HierarchicalCollectionEvent):Void {
		if (this._selectedLocation == null) {
			return;
		}

		var comparisonResult = this.compareLocations(this._selectedLocation, event.location);
		if (comparisonResult == 0) {
			// use the setter
			this.selectedLocation = null;
		} else if (comparisonResult > 0) {
			// use the setter
			this.selectedLocation = this._dataProvider.locationOf(this._selectedItem);
		}
	}

	private function treeView_dataProvider_replaceItemHandler(event:HierarchicalCollectionEvent):Void {
		if (this._selectedLocation == null) {
			return;
		}
		if (this.compareLocations(this._selectedLocation, event.location) == 0) {
			this._selectedItem = this._dataProvider.get(event.location);
			FeathersEvent.dispatch(this, Event.CHANGE);
		}
	}

	private function treeView_dataProvider_removeAllHandler(event:HierarchicalCollectionEvent):Void {
		// use the setter
		this.selectedLocation = null;
	}

	private function treeView_dataProvider_resetHandler(event:HierarchicalCollectionEvent):Void {
		// use the setter
		this.selectedLocation = null;
	}

	private function updateItemRendererForLocation(location:Array<Int>):Void {
		var item = this._dataProvider.get(location);
		var itemRenderer = this.dataToItemRenderer.get(item);

		if (itemRenderer == null) {
			// doesn't exist yet, so we need to do a full invalidation
			this.setInvalid(DATA);
			return;
		}
		// in order to display the same item with modified properties, this
		// hack tricks the item renderer into thinking that it has been given
		// a different item to render.
		if (Std.is(itemRenderer, IDataRenderer)) {
			cast(itemRenderer, IDataRenderer).data = null;
		}
		var layoutIndex = this.dataToLayoutIndex.get(item);
		this.refreshItemRendererProperties(itemRenderer, item, location, layoutIndex);
		if (this._dataProvider.isBranch(item)) {
			for (i in 0...this._dataProvider.getLength(location)) {
				location.push(i);
				this.updateItemRendererForLocation(location);
				location.pop();
			}
		}
	}

	private function treeView_dataProvider_updateItemHandler(event:HierarchicalCollectionEvent):Void {
		this.updateItemRendererForLocation(event.location);
	}

	private function treeView_dataProvider_updateAllHandler(event:HierarchicalCollectionEvent):Void {
		var location:Array<Int> = [];
		for (i in 0...this._dataProvider.getLength()) {
			location[0] = i;
			this.updateItemRendererForLocation(location);
		}
	}
}
