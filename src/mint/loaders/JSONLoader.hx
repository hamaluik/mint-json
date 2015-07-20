package mint.loaders;

import haxe.ds.StringMap;
import mint.Button.ButtonOptions;
import mint.Canvas;
import mint.Canvas.CanvasOptions;
import mint.Checkbox.CheckboxOptions;
import mint.Control;
import mint.Dropdown.DropdownOptions;
import mint.Image.ImageOptions;
import mint.Label.LabelOptions;
import mint.render.Rendering;
import mint.types.Types.MouseEvent;

using StringTools;

// called when the parser hits a control it doesn't know about
// gives the type and its supplied options as parameters, expects a constructed control back
typedef Callback_UnknownControl = String->Dynamic->Control;

// called when the parser hits a control with a missing mandatory field
// gives the control name, control type and field name as parameters, expects the value of the field back
typedef Callback_MissingField = String->String->String->Dynamic;

// called when the parser hits a control with a "onclick" or "onchange" interaction
// gives the control and JSON value provided
typedef Callback_ControlInteraction = Control->Dynamic->Void;

class JSONLoader {
	// utility to take care of unnamed controls
	// will assign control names based on their type and the number of that control
	// in a specific type
	private static var unnamedControlIndices:StringMap<Int> = new StringMap<Int>();
	private static function GetUnnamedControlIndex(type:String):String {
		var ret:String = "x";
		if(unnamedControlIndices.exists(type)) {
			var i:Int = unnamedControlIndices.get(type);
			ret = Std.string(i);
			unnamedControlIndices.set(type, i + 1);
		}
		else {
			unnamedControlIndices.set(type, 0);
			ret = "0";
		}
		return ret;
	} // GetUnnamedControlIndex
	
	private function new() {}
	
	public static function Load(json:Dynamic, parent:Control,
	                            ?rendering:mint.render.Rendering,
	                            ?OnUnknownControl:Callback_UnknownControl, ?OnMissingField:Callback_MissingField,
	                            ?OnClick:Callback_ControlInteraction, ?OnChange:Callback_ControlInteraction):Array<Control> {
		var loadedControls:Array<Control> = new Array<Control>();
		
		var children:Array<String> = Reflect.fields(json);
		for(c in children) {
			// get the actual object
			var wrapper = Reflect.field(json, c);
			
			// figure out what type it is
			var controlType:String = Std.string(Reflect.fields(wrapper)[0]);
			
			// get the actual control
			var options = Reflect.field(wrapper, controlType);
			
			// which is made of two parts:
			//var options = control.options;
			var grandChildren = options.children;
			
			// get the name of the control
			var controlName = options.name;
			// if there is no name, use a unique one
			if(controlName == null) {
				controlName = controlType + "." + GetUnnamedControlIndex(controlType);
				options.name = controlName;
			}
			
			// inject the parent
			options.parent = parent;
			
			// and the rendering
			options.rendering = rendering;
			
			// load it (with its options)
			var loadedControl = switch(controlType.toLowerCase()) {
				case 'button': new mint.Button(TranslateOptions(options, { text: '' }, '', OnMissingField, OnClick, OnChange));
				case 'canvas': new mint.Canvas(TranslateOptions(options, {}, '', OnMissingField, OnClick, OnChange));
				case 'checkbox': new mint.Checkbox(TranslateOptions(options, {}, '', OnMissingField, OnClick, OnChange));
				case 'dropdown': new mint.Dropdown(TranslateOptions(options, { text: '' }, '', OnMissingField, OnClick, OnChange));
				case 'image': new mint.Image(TranslateOptions(options, { path: '' }, '', OnMissingField, OnClick, OnChange));
				case 'label': new mint.Label(TranslateOptions(options, { text: '' }, '', OnMissingField, OnClick, OnChange));
				case 'list': new mint.List(TranslateOptions(options, {}, '', OnMissingField, OnClick, OnChange));
				case 'panel': new mint.Panel(TranslateOptions(options, {}, '', OnMissingField, OnClick, OnChange));
				case 'progress': new mint.Progress(TranslateOptions(options, {}, '', OnMissingField, OnClick, OnChange));
				case 'scroll': new mint.Scroll(TranslateOptions(options, {}, '', OnMissingField, OnClick, OnChange));
				case 'slider': new mint.Slider(TranslateOptions(options, {}, '', OnMissingField, OnClick, OnChange));
				case 'textedit': new mint.TextEdit(TranslateOptions(options, {}, '', OnMissingField, OnClick, OnChange));
				case 'window': new mint.Window(TranslateOptions(options, {}, '', OnMissingField, OnClick, OnChange));
				default: if(OnUnknownControl != null) OnUnknownControl(controlType, options); else null;
			};
			if(loadedControl != null) loadedControls.push(loadedControl);
			
			// recurse!
			if(grandChildren != null) {
				var loadedChildren:Array<Control> = Load(grandChildren, loadedControl);
				loadedControls = loadedControls.concat(loadedChildren);
			}
		}
		
		return loadedControls;
	} // Load
	
	private static function TranslateOptions<T>(options:Dynamic, typeOptions:T,
	                                            controlType:String,
	                                            ?OnMissingField:Callback_MissingField,
	                                            ?OnClick:Callback_ControlInteraction, ?OnChange:Callback_ControlInteraction):T {
		// make sure the user provided the correct options!
		var fieldNames:Array<String> = Reflect.fields(typeOptions);
		for(mandatoryField in fieldNames) {
			var suppliedValue = Reflect.field(options, mandatoryField);
			if(suppliedValue == null) {
				Reflect.setField(typeOptions, mandatoryField, OnMissingField(options.name, controlType, mandatoryField));
			}
		}
		
		// loop through all the specified options
		// and set them in the strongly-typed version
		var optionNames:Array<String> = Reflect.fields(options);
		for(optionName in optionNames) {
			var val:Dynamic = Reflect.field(options, optionName);
			
			// deal with special items
			switch(optionName) {
				case 'align': Reflect.setField(typeOptions, optionName, TranslateTextAlign(val));
				case 'align_vertical': Reflect.setField(typeOptions, optionName, TranslateTextAlign(val));
				
				case 'onclick': {
					if(OnClick != null) {
						Reflect.setField(typeOptions, optionName, function(event:MouseEvent, control:Control):Void {
							OnClick(control, val);
						});
					}
				}
				
				case 'onchange': {
					if(OnChange != null) {
						Reflect.setField(typeOptions, optionName, function(event:MouseEvent, control:Control):Void {
							OnChange(control, val);
						});
					}
				}
				
				case 'options': {
					var too:Dynamic = {};
					TranslateOptions(options.options, too, '', OnMissingField, OnClick, OnChange);
					Reflect.setField(typeOptions, optionName, too);
				}
				
				// skip the "children" field in this function
				case 'children': continue;
				
				default: {
					if(optionName.startsWith("color")) {
						// translate colours
						Reflect.setField(typeOptions, optionName, new luxe.Color().rgb(Std.parseInt(val)));
					}
					else {
						Reflect.setField(typeOptions, optionName, val);
					}
				}
			}
		}
		
		return typeOptions;
	} // TranslateOptions
	
	private static function TranslateTextAlign(align:String):mint.types.Types.TextAlign {
		return switch(align) {
			case 'left': mint.types.Types.TextAlign.left;
			case 'right': mint.types.Types.TextAlign.right;
			case 'center': mint.types.Types.TextAlign.left;
			case 'top': mint.types.Types.TextAlign.top;
			case 'bottom': mint.types.Types.TextAlign.bottom;
			default: mint.types.Types.TextAlign.unknown;
		}
	} // TranslateTextAlign
}