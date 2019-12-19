/*
	Feathers UI
	Copyright 2019 Bowler Hat LLC. All Rights Reserved.

	This program is free software. You can redistribute and/or modify it in
	accordance with the terms of the accompanying license agreement.
 */

package feathers.controls;

import openfl.events.FocusEvent;
import feathers.controls.dataRenderers.ItemRenderer;
import feathers.utils.DisplayObjectRecycler;
import feathers.data.ListViewItemState;
import openfl.display.DisplayObject;
import feathers.themes.steel.components.SteelComboBoxStyles;
import openfl.events.TouchEvent;
import lime.ui.KeyCode;
import openfl.ui.Keyboard;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import feathers.events.FeathersEvent;
import openfl.events.Event;
import feathers.core.InvalidationFlag;
import feathers.data.IFlatCollection;
import feathers.layout.Measurements;
import feathers.controls.popups.IPopUpAdapter;
import feathers.core.FeathersControl;
import feathers.core.IDataSelector;
import feathers.controls.popups.DropDownPopUpAdapter;

/**
	Displays a control consisting of a `TextInput` and `Button` that allows an
	item from a collection to be selected. When the button is triggered, a list
	box of items is displayed as a pop-up. The text input allows filtering, or
	(optionally) choosing custom items.

	The following example creates a `ComboBox`, gives it a data provider, tells
	the item renderer how to interpret the data, and listens for when the
	selection changes:

	```hx
	var comboBox = new ComboBox();

	comboBox.dataProvider = new ArrayCollection(
	[
		{ text: "Milk" },
		{ text: "Eggs" },
		{ text: "Bread" },
		{ text: "Steak" },
	]);

	comboBox.itemToText = (item:Dynamic) ->
	{
		return item.text;
	};

	comboBox.addEventListener(Event.CHANGE, (event:Event) ->
	{
		trace("ComboBox changed: " + comboBox.selectedIndex + " " + comboBox.selectedItem.text);
	});

	this.addChild(comboBox);
	```

	@see [Tutorial: How to use the ComboBox component](https://feathersui.com/learn/haxe-openfl/combo-box/)
	@see `feathers.controls.PopUpList`

	@since 1.0.0
**/
@:styleContext
class ComboBox extends FeathersControl implements IDataSelector<Dynamic> {
	private static final INVALIDATION_FLAG_BUTTON_FACTORY = "buttonFactory";
	private static final INVALIDATION_FLAG_TEXT_INPUT_FACTORY = "textInputFactory";
	private static final INVALIDATION_FLAG_LIST_VIEW_FACTORY = "listViewFactory";

	/**
		The variant used to style the `Button` child component in a theme.

		@see [Feathers UI User Manual: Themes](https://feathersui.com/learn/haxe-openfl/themes/)
	**/
	public static final CHILD_VARIANT_BUTTON = "comboBoxButton";

	/**
		The variant used to style the `TextInput` child component in a theme.

		@see [Feathers UI User Manual: Themes](https://feathersui.com/learn/haxe-openfl/themes/)
	**/
	public static final CHILD_VARIANT_TEXT_INPUT = "comboBoxButton";

	/**
		The variant used to style the `ListView` child component in a theme.

		@see [Feathers UI User Manual: Themes](https://feathersui.com/learn/haxe-openfl/themes/)
	**/
	public static final CHILD_VARIANT_LIST_VIEW = "comboBoxListView";

	/**
		Creates a new `ComboBox` object.

		@since 1.0.0
	**/
	public function new() {
		initializeComboBoxTheme();

		super();
		this.addEventListener(KeyboardEvent.KEY_UP, comboBox_keyUpHandler);
	}

	private var button:Button;
	private var textInput:TextInput;
	private var listView:ListView;

	private var buttonMeasurements = new Measurements();
	private var textInputMeasurements = new Measurements();

	/**
		The collection of data displayed by the list.

		The following example passes in a data provider and tells the item
		renderer how to interpret the data:

		```hx
		comboBox.dataProvider = new ArrayCollection(
		[
			{ text: "Milk" },
			{ text: "Eggs" },
			{ text: "Bread" },
			{ text: "Chicken" },
		]);

		comboBox.itemToText = (item:Dynamic) ->
		{
			return item.text;
		};
		```

		@default null

		@see `feathers.data.ArrayCollection`

		@since 1.0.0
	**/
	public var dataProvider(default, set):IFlatCollection<Dynamic> = null;

	private function set_dataProvider(value:IFlatCollection<Dynamic>):IFlatCollection<Dynamic> {
		if (this.dataProvider == value) {
			return this.dataProvider;
		}
		var oldSelectedIndex = this.selectedIndex;
		var oldSelectedItem = this.selectedItem;
		this.dataProvider = value;
		if (this.dataProvider == null || this.dataProvider.length == 0) {
			this.selectedIndex = -1;
		} else {
			this.selectedIndex = 0;
		}
		// this ensures that Event.CHANGE will dispatch for selectedItem
		// changing, even if selectedIndex has not changed.
		if (this.selectedIndex == oldSelectedIndex && this.selectedItem != oldSelectedItem) {
			this.setInvalid(InvalidationFlag.SELECTION);
			FeathersEvent.dispatch(this, Event.CHANGE);
		}
		if (this.dataProvider != null) {
			this.dataProvider.filterFunction = this.comboBoxFilterFunction;
		}
		this.setInvalid(InvalidationFlag.DATA);
		return this.dataProvider;
	}

	private var pendingSelectedIndex = -1;
	private var pendingSelectedItem:Dynamic = null;

	/**
		@see `feathers.core.IDataSelector.selectedIndex`
	**/
	@:isVar
	public var selectedIndex(get, set):Int = -1;

	private function get_selectedIndex():Int {
		return this.selectedIndex;
	}

	private function set_selectedIndex(value:Int):Int {
		if (this.dataProvider == null) {
			value = -1;
		}
		if (this.selectedIndex == value) {
			return this.selectedIndex;
		}
		this.selectedIndex = value;
		// using @:bypassAccessor because if we were to call the selectedItem
		// setter, this change wouldn't be saved properly
		if (this.selectedIndex == -1) {
			@:bypassAccessor this.selectedItem = null;
		} else {
			@:bypassAccessor this.selectedItem = this.dataProvider.get(this.selectedIndex);
		}
		this.setInvalid(InvalidationFlag.SELECTION);
		FeathersEvent.dispatch(this, Event.CHANGE);
		return this.selectedIndex;
	}

	/**
		@see `feathers.core.IDataSelector.selectedItem`
	**/
	@:isVar
	public var selectedItem(get, set):Dynamic = null;

	private function get_selectedItem():Int {
		return this.selectedItem;
	}

	private function set_selectedItem(value:Dynamic):Dynamic {
		if (this.dataProvider == null) {
			this.selectedIndex = -1;
			return this.selectedItem;
		}
		this.selectedIndex = this.dataProvider.indexOf(value);
		return this.selectedItem;
	}

	/**
		Manages item renderers used by the list view.

		In the following example, the pop-up list view uses a custom item
		renderer:

		```hx
		comboBox.itemRendererRecycler = new DisplayObjectRecycler(CustomItemRenderer);
		```

		@since 1.0.0
	**/
	public var itemRendererRecycler(default, set):DisplayObjectRecycler<Dynamic, ListViewItemState, DisplayObject> = new DisplayObjectRecycler(ItemRenderer);

	private function set_itemRendererRecycler(value:DisplayObjectRecycler<Dynamic, ListViewItemState, DisplayObject>):DisplayObjectRecycler<Dynamic,
		ListViewItemState, DisplayObject> {
		if (this.itemRendererRecycler == value) {
			return this.itemRendererRecycler;
		}
		this.itemRendererRecycler = value;
		this.setInvalid(InvalidationFlag.DATA);
		return this.itemRendererRecycler;
	}

	/**
		Converts an item to text to display within the pop-up `ListView`, or
		within the `Button`, if the item is selected. By default, the
		`toString()` method is called to convert an item to text. This method
		may be replaced to provide custom text.

		For example, consider the following item:

		```hx
		{ text: "Example Item" }
		```

		If the `ListView` should display the text "Example Item", a custom
		implementation of `itemToText()` might look like this:

		```hx
		comboBox.itemToText = (item:Dynamic) ->
		{
			return item.text;
		};
		```

		@since 1.0.0
	**/
	public dynamic function itemToText(data:Dynamic):String {
		return Std.string(data);
	}

	private var _ignoreTextInputChange = false;
	private var _ignoreListViewChange = false;

	/**
		Manages how the pop-up list is displayed when it is opened and closed.

		In the following example, a custom pop-up adapter is provided:

		```hx
		comboBox.popUpAdapter = new DropDownPopUpAdapter();
		```

		@since 1.0.0
	**/
	@:style
	public var popUpAdapter:IPopUpAdapter = new DropDownPopUpAdapter();

	/**
		Indicates if the pop-up list is open or closed.

		@see `ComboBox.openList()`
		@see `ComboBox.closeList()`

		@since 1.0.0
	**/
	public var open(get, never):Bool;

	private function get_open():Bool {
		return this.listView.parent != null;
	}

	private var _filterText:String = "";

	/**
		Opens the pop-up list, if it is not already open.

		The following example opens the pop-up list:

		```hx
		if(!comboBox.open)
		{
			comboBox.openList();
		}
		```

		@see `ComboBox.open`
		@see `ComboBox.closeList()`

		@since 1.0.0
	**/
	public function openList():Void {
		if (this.open || this.stage == null) {
			return;
		}
		this._filterText = "";
		if (this.dataProvider != null) {
			this.dataProvider.refresh();
		}
		this.pendingSelectedItem = this.selectedItem;
		this.popUpAdapter.addEventListener(Event.CLOSE, comboBox_popUpAdapter_closeHandler);
		this.popUpAdapter.open(this.listView, this);
		this.listView.addEventListener(Event.REMOVED_FROM_STAGE, comboBox_listView_removedFromStageHandler);
		this.stage.addEventListener(MouseEvent.MOUSE_DOWN, comboBox_stage_mouseDownHandler, false, 0, true);
		this.stage.addEventListener(TouchEvent.TOUCH_BEGIN, comboBox_stage_touchBeginHandler, false, 0, true);
	}

	/**
		Closes the pop-up list, if it is open.

		The following example closes the pop-up list:

		```hx
		if(comboBox.open)
		{
			comboBox.closeList();
		}
		```

		@see `ComboBox.open`
		@see `ComboBox.openList()`

		@since 1.0.0
	**/
	public function closeList():Void {
		if (!this.open) {
			return;
		}
		this.popUpAdapter.close();
	}

	private function initializeComboBoxTheme():Void {
		SteelComboBoxStyles.initialize();
	}

	override private function update():Void {
		var buttonFactoryInvalid = this.isInvalid(INVALIDATION_FLAG_BUTTON_FACTORY);
		var textInputFactoryInvalid = this.isInvalid(INVALIDATION_FLAG_TEXT_INPUT_FACTORY);
		var listViewFactoryInvalid = this.isInvalid(INVALIDATION_FLAG_LIST_VIEW_FACTORY);
		var dataInvalid = this.isInvalid(InvalidationFlag.DATA);
		var selectionInvalid = this.isInvalid(InvalidationFlag.SELECTION);
		var stateInvalid = this.isInvalid(InvalidationFlag.STATE);

		if (buttonFactoryInvalid) {
			this.createButton();
		}
		if (textInputFactoryInvalid) {
			this.createTextInput();
		}
		if (listViewFactoryInvalid) {
			this.createListView();
		}

		if (dataInvalid || listViewFactoryInvalid) {
			this.refreshData();
		}

		if (selectionInvalid || listViewFactoryInvalid || buttonFactoryInvalid) {
			this.refreshSelection();
		}

		if (stateInvalid || listViewFactoryInvalid || buttonFactoryInvalid) {
			this.refreshEnabled();
		}

		this.autoSizeIfNeeded();
		this.layoutChildren();
	}

	private function createButton():Void {
		if (this.button != null) {
			this.button.removeEventListener(FeathersEvent.TRIGGERED, button_triggeredHandler);
			this.button = null;
		}
		this.button = new Button();
		this.button.variant = ComboBox.CHILD_VARIANT_BUTTON;
		this.button.addEventListener(FeathersEvent.TRIGGERED, button_triggeredHandler);
		this.button.initializeNow();
		this.buttonMeasurements.save(this.button);
		this.addChild(this.button);
	}

	private function createTextInput():Void {
		if (this.textInput != null) {
			this.textInput.removeEventListener(Event.CHANGE, textInput_changeHandler);
			this.textInput.removeEventListener(FocusEvent.FOCUS_IN, textInput_focusInHandler);
			this.textInput = null;
		}
		this.textInput = new TextInput();
		this.textInput.variant = ComboBox.CHILD_VARIANT_TEXT_INPUT;
		this.textInput.addEventListener(Event.CHANGE, textInput_changeHandler);
		this.textInput.addEventListener(FocusEvent.FOCUS_IN, textInput_focusInHandler);
		this.button.initializeNow();
		this.textInputMeasurements.save(this.textInput);
		this.addChild(this.textInput);
	}

	private function createListView():Void {
		if (this.listView != null) {
			this.listView.removeEventListener(FeathersEvent.TRIGGERED, listView_triggeredHandler);
			this.listView.removeEventListener(Event.CHANGE, listView_changeHandler);
			this.listView = null;
		}
		this.listView = new ListView();
		this.listView.variant = ComboBox.CHILD_VARIANT_LIST_VIEW;
		this.listView.addEventListener(FeathersEvent.TRIGGERED, listView_triggeredHandler);
		this.listView.addEventListener(Event.CHANGE, listView_changeHandler);
	}

	private function refreshData():Void {
		this.listView.dataProvider = this.dataProvider;
		this.listView.itemRendererRecycler = this.itemRendererRecycler;
		this.listView.itemToText = this.itemToText;
	}

	private function refreshSelection():Void {
		var oldIgnoreListViewChange = this._ignoreListViewChange;
		this._ignoreListViewChange = true;
		this.listView.selectedIndex = this.selectedIndex;
		this._ignoreListViewChange = oldIgnoreListViewChange;

		var oldIgnoreTextInputChange = this._ignoreTextInputChange;
		this._ignoreTextInputChange = true;
		if (this.selectedItem != null) {
			this.textInput.text = this.itemToText(this.selectedItem);
		} else {
			this.textInput.text = "";
		}
		this._ignoreTextInputChange = oldIgnoreTextInputChange;
	}

	private function refreshEnabled():Void {
		this.button.enabled = this.enabled;
		this.textInput.enabled = this.enabled;
		this.listView.enabled = this.enabled;
	}

	private function comboBoxFilterFunction(item:Dynamic):Bool {
		if (this._filterText.length == 0) {
			return true;
		}
		var itemText = this.itemToText(item).toLowerCase();
		return itemText.indexOf(this._filterText.toLowerCase()) != -1;
	}

	private function autoSizeIfNeeded():Bool {
		var needsWidth = this.explicitWidth == null;
		var needsHeight = this.explicitHeight == null;
		var needsMinWidth = this.explicitMinWidth == null;
		var needsMinHeight = this.explicitMinHeight == null;
		var needsMaxWidth = this.explicitMaxWidth == null;
		var needsMaxHeight = this.explicitMaxHeight == null;
		if (!needsWidth && !needsHeight && !needsMinWidth && !needsMinHeight && !needsMaxWidth && !needsMaxHeight) {
			return false;
		}

		this.buttonMeasurements.restore(this.button);
		this.button.validateNow();

		this.textInputMeasurements.restore(this.textInput);
		this.textInput.validateNow();

		var newWidth = this.explicitWidth;
		if (needsWidth) {
			newWidth = this.button.width + this.textInput.width;
		}

		var newHeight = this.explicitHeight;
		if (needsHeight) {
			newHeight = Math.max(this.button.height, this.textInput.height);
		}

		var newMinWidth = this.explicitMinWidth;
		if (needsMinWidth) {
			newMinWidth = this.button.minWidth + this.textInput.minWidth;
		}

		var newMinHeight = this.explicitMinHeight;
		if (needsMinHeight) {
			newMinHeight = Math.max(this.button.minHeight, this.textInput.minHeight);
		}

		return this.saveMeasurements(newWidth, newHeight, newMinWidth, newMinHeight);
	}

	private function layoutChildren():Void {
		this.button.validateNow();
		this.button.x = this.actualWidth - this.button.width;
		this.button.y = 0.0;
		if (this.button.height != this.actualHeight) {
			this.button.height = this.actualHeight;
		}
		this.textInput.x = 0.0;
		this.textInput.y = 0.0;
		var textInputWidth = this.actualWidth - this.button.width;
		if (this.textInput.width != textInputWidth) {
			this.textInput.width = textInputWidth;
		}
		if (this.textInput.height != this.actualHeight) {
			this.textInput.height = this.actualHeight;
		}
		this.button.validateNow();
		this.textInput.validateNow();
	}

	private function textInput_changeHandler(event:Event):Void {
		if (this._ignoreTextInputChange) {
			return;
		}
		if (!this.open) {
			this.openList();
		}
		if (this.dataProvider != null) {
			this._filterText = this.textInput.text;
			this.dataProvider.refresh();
		}
	}

	private function textInput_focusInHandler(event:FocusEvent):Void {
		if (!this.open) {
			this.openList();
		}
	}

	private function button_triggeredHandler(event:FeathersEvent):Void {
		if (this.open) {
			this.closeList();
		} else {
			this.openList();
		}
	}

	private function listView_triggeredHandler(event:Event):Void {
		if (!this.popUpAdapter.persistent) {
			this.closeList();
		}
	}

	private function listView_changeHandler(event:Event):Void {
		if (this._ignoreListViewChange) {
			return;
		}
		if (this.open) {
			// if the list is open, save the selected index for later
			this.pendingSelectedIndex = this.listView.selectedIndex;
		} else {
			// if closed, update immediately
			this.pendingSelectedIndex = -1;
			this.selectedIndex = this.listView.selectedIndex;
		}
	}

	private function comboBox_listView_removedFromStageHandler(event:Event):Void {
		this.listView.removeEventListener(Event.REMOVED_FROM_STAGE, comboBox_listView_removedFromStageHandler);
		this.stage.removeEventListener(MouseEvent.MOUSE_DOWN, comboBox_stage_mouseDownHandler);
		this.stage.removeEventListener(TouchEvent.TOUCH_BEGIN, comboBox_stage_touchBeginHandler);
	}

	private function comboBox_keyUpHandler(event:KeyboardEvent):Void {
		if (!this.enabled) {
			return;
		}
		switch (event.keyCode) {
			case Keyboard.ESCAPE:
				if (event.isDefaultPrevented()) {
					return;
				}
				if (!this.open) {
					return;
				}
				event.preventDefault();
				this.closeList();
			case KeyCode.APP_CONTROL_BACK:
				if (event.isDefaultPrevented()) {
					return;
				}
				if (!this.open) {
					return;
				}
				event.preventDefault();
				this.closeList();
		}
	}

	private function comboBox_stage_mouseDownHandler(event:MouseEvent):Void {
		if (this.hitTestPoint(event.stageX, event.stageY) || this.listView.hitTestPoint(event.stageX, event.stageY)) {
			return;
		}
		this.closeList();
	}

	private function comboBox_stage_touchBeginHandler(event:TouchEvent):Void {
		if (event.isPrimaryTouchPoint) {
			// ignore the primary one because MouseEvent.MOUSE_DOWN will catch it
			return;
		}
		if (this.hitTestPoint(event.stageX, event.stageY) || this.listView.hitTestPoint(event.stageX, event.stageY)) {
			return;
		}
		this.closeList();
	}

	private function comboBox_popUpAdapter_closeHandler(event:Event):Void {
		this.popUpAdapter.removeEventListener(Event.CLOSE, comboBox_popUpAdapter_closeHandler);

		var newSelectedItem = this.pendingSelectedItem;
		if (this.pendingSelectedIndex != -1) {
			newSelectedItem = this.dataProvider.get(this.pendingSelectedIndex);
		} else {
			var filterText = this._filterText.toLowerCase();
			if (this.dataProvider.length > 0) {
				for (item in this.dataProvider) {
					var itemText = this.itemToText(item).toLowerCase();
					if (itemText == filterText) {
						// if the filtered data contains a match, use it
						// otherwise, fall back to the previous item
						newSelectedItem = item;
						break;
					}
				}
			}
		}
		this._filterText = "";
		this.pendingSelectedIndex = -1;
		this.pendingSelectedItem = null;
		if (this.dataProvider != null) {
			this.dataProvider.refresh();
		}
		this.selectedItem = newSelectedItem;
		// even if the selected item has not changed, invalidate because the
		// displayed text may need to be updated
		this.setInvalid(InvalidationFlag.SELECTION);
	}
}
