/*
	Feathers UI
	Copyright 2020 Bowler Hat LLC. All Rights Reserved.

	This program is free software. You can redistribute and/or modify it in
	accordance with the terms of the accompanying license agreement.
 */

package feathers.skins;

import feathers.graphics.FillStyle;
import feathers.graphics.LineStyle;
import feathers.layout.RelativePosition;
import openfl.errors.ArgumentError;

/**
	A skin for Feathers UI components that draws a triangle pointing in one of
	the four cardinal directions. The triangle's fill and border may be styled,
	and the position of the primary point may be customized.

	@since 1.0.0
**/
class TriangleSkin extends BaseGraphicsPathSkin {
	/**
		Creates a new `RectangleSkin` object.

		@since 1.0.0
	**/
	public function new(?fill:FillStyle, ?border:LineStyle) {
		super(fill, border);
	}

	private var _pointPosition:RelativePosition = TOP;

	/**
		The triangle may point in any of the four cardinal directions.

		@since 1.0.0
	**/
	@:flash.property
	public var pointPosition(get, set):RelativePosition;

	private function get_pointPosition():RelativePosition {
		return this._pointPosition;
	}

	private function set_pointPosition(value:RelativePosition):RelativePosition {
		if (this._pointPosition == value) {
			return this._pointPosition;
		}
		this._pointPosition = value;
		this.setInvalid(STYLES);
		return this._pointPosition;
	}

	private var _drawBaseBorder:Bool = true;

	/**
		The triangle's base border can be drawn or not

		@since 1.0.0
	**/
	@:flash.property
	public var drawBaseBorder(get, set):Bool;

	private function get_drawBaseBorder():Bool {
		return this._drawBaseBorder;
	}

	private function set_drawBaseBorder(value:Bool):Bool {
		if (this._drawBaseBorder == value) {
			return this._drawBaseBorder;
		}
		this._drawBaseBorder = value;
		this.setInvalid(STYLES);
		return this._drawBaseBorder;
	}

	private var _cornerRadius:Float = 0.0;

	/**
		The rectangle may optionally have rounded corners, and this sets their
		radius, measured in pixels.

		@since 1.0.0
	**/
	@:flash.property
	public var cornerRadius(get, set):Float;

	private function get_cornerRadius():Float {
		return this._cornerRadius;
	}

	private function set_cornerRadius(value:Float):Float {
		if (this._cornerRadius == value) {
			return this._cornerRadius;
		}
		this._cornerRadius = value;
		this.setInvalid(STYLES);
		return this._cornerRadius;
	}

	override private function drawPath():Void {
		var currentBorder = this.getCurrentBorder();
		var thicknessOffset = getLineThickness(currentBorder) / 2.0;

		switch (this._pointPosition) {
			case LEFT:
				if (this._drawBaseBorder) {
					this.graphics.moveTo(this.actualWidth - thicknessOffset, thicknessOffset);
					this.graphics.lineTo(this.actualWidth - thicknessOffset, this.actualHeight - thicknessOffset);
				} else {
					this.graphics.moveTo(this.actualWidth, thicknessOffset);
					this.graphics.lineStyle(0.0, 0.0, 0.0);
					this.graphics.lineTo(this.actualWidth, this.actualHeight - thicknessOffset);
					this.applyLineStyle(currentBorder);
				}
				this.graphics.lineTo(thicknessOffset, this.actualHeight / 2.0);
				if (this._drawBaseBorder) {
					this.graphics.lineTo(this.actualWidth - thicknessOffset, thicknessOffset);
				} else {
					this.graphics.lineTo(this.actualWidth, thicknessOffset);
				}
			case RIGHT:
				if (this._drawBaseBorder) {
					this.graphics.moveTo(thicknessOffset, thicknessOffset);
				} else {
					this.graphics.moveTo(0.0, thicknessOffset);
				}
				this.graphics.lineTo(this.actualWidth - thicknessOffset, this.actualHeight / 2.0);
				if (this._drawBaseBorder) {
					this.graphics.lineTo(thicknessOffset, this.actualHeight - thicknessOffset);
					this.graphics.lineTo(thicknessOffset, thicknessOffset);
				} else {
					this.graphics.lineTo(0.0, this.actualHeight - thicknessOffset);
					this.graphics.lineStyle(0.0, 0.0, 0.0);
					this.graphics.lineTo(0.0, thicknessOffset);
					this.applyLineStyle(currentBorder);
				}
			case TOP:
				this.graphics.moveTo(this.actualWidth / 2.0, thicknessOffset);
				if (this._drawBaseBorder) {
					this.graphics.lineTo(this.actualWidth - thicknessOffset, this.actualHeight - thicknessOffset);
					this.graphics.lineTo(thicknessOffset, this.actualHeight - thicknessOffset);
				} else {
					this.graphics.lineTo(this.actualWidth - thicknessOffset, this.actualHeight);
					this.graphics.lineStyle(0.0, 0.0, 0.0);
					this.graphics.lineTo(thicknessOffset, this.actualHeight);
					this.applyLineStyle(currentBorder);
				}
				this.graphics.lineTo(this.actualWidth / 2.0, thicknessOffset);
			case BOTTOM:
				if (this._drawBaseBorder) {
					this.graphics.moveTo(thicknessOffset, thicknessOffset);
					this.graphics.lineTo(this.actualWidth - thicknessOffset, thicknessOffset);
				} else {
					this.graphics.lineStyle(0.0, 0.0, 0.0);
					this.graphics.moveTo(thicknessOffset, 0.0);
					this.graphics.lineTo(this.actualWidth - thicknessOffset, 0.0);
					this.applyLineStyle(currentBorder);
				}
				this.graphics.lineTo(this.actualWidth / 2.0, this.actualHeight - thicknessOffset);
				if (this._drawBaseBorder) {
					this.graphics.lineTo(thicknessOffset, thicknessOffset);
				} else {
					this.graphics.lineTo(thicknessOffset, 0.0);
				}
			default:
				throw new ArgumentError("Triangle pointPosition not supported: " + this._pointPosition);
		}
	}
}
