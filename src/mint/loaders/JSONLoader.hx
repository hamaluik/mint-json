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

class JSONLoaderException {
	public var message:String;
	
	public function new(message:String) {
		this.message = message;
	}
}

class JSONLoader {
	public var canvases:Array<Canvas> = new Array<Canvas>();
	public var rendering:Rendering;
	public var layout:mint.layout.margins.Margins; // TODO: generic layout interface?
	
	public var controls:StringMap<Control> = new StringMap<Control>();
	
	// utility to take care of unnamed controls
	// will assign control names based on their type and the number of that control
	// in a specific type
	private var unnamedControlIndices:StringMap<Int> = new StringMap<Int>();
	private function GetUnnamedControlIndex(type:String):String {
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
	
	public function new(?jsonString:String, ?jsonObject:Dynamic) {
		if(jsonString != null) {
			FromJSONString(jsonString);
		}
		else if(jsonObject != null) {
			FromJSONObject(jsonObject);
		}
	} // new
	
	public function FromJSONString(JSON:String) {
		FromJSONObject(haxe.Json.parse(JSON));
	} // FromJSONString
	
	public function FromJSONObject(JSON:Dynamic) {
		// initialize mint
		rendering = switch(JSON.rendering) {
			case 'luxe': new mint.render.luxe.LuxeMintRender();
			default: throw new JSONLoaderException("Unknown rendering '" + JSON.rendering + "'!");
		}
		
		layout = switch(JSON.layout) {
			case 'margins': new mint.layout.margins.Margins();
			default: throw new JSONLoaderException("Unknown layout engine '" + JSON.layout + "'!");
		}
		
		// recursively load everything
		if(JSON.canvases == null) throw new JSONLoader("No canvases are defined!");
		LoadControls(JSON.canvases, null, "");
	} // FromJSONObject
	
	private function LoadControls(root:Dynamic, parent:Control, tabLevel:String):Void {
		var children:Array<String> = Reflect.fields(root);
		for(c in children) {
			// get the actual object
			var wrapper = Reflect.field(root, c);
			
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
				case 'button': new mint.Button(TranslateControlOptions(options, { text: '' }));
				case 'canvas': new mint.Canvas(TranslateControlOptions(options, {}));
				case 'checkbox': new mint.Checkbox(TranslateControlOptions(options, {}));
				case 'dropdown': new mint.Dropdown(TranslateControlOptions(options, { text: '' }));
				case 'image': new mint.Image(TranslateControlOptions(options, { path: '' }));
				case 'label': new mint.Label(TranslateControlOptions(options, { text: '' }));
				case 'list': new mint.List(TranslateControlOptions(options, {}));
				case 'panel': new mint.Panel(TranslateControlOptions(options, {}));
				case 'progress': new mint.Progress(TranslateControlOptions(options, {}));
				case 'scroll': new mint.Scroll(TranslateControlOptions(options, {}));
				case 'slider': new mint.Slider(TranslateControlOptions(options, {}));
				case 'textedit': new mint.TextEdit(TranslateControlOptions(options, {}));
				case 'window': new mint.Window(TranslateControlOptions(options, {}));
				default: throw new JSONLoaderException("Unknown control type '" + controlType + "'!");
			};
			controls.set(controlName, loadedControl);
			
			// debug message
			trace("Loaded " + tabLevel + controlType + ": '" + controlName + "'!");
			
			// recurse!
			if(grandChildren != null) {
				LoadControls(grandChildren, loadedControl, tabLevel + "  ");
			}
			
			// if we loaded a canvas, record it for event processing
			if(controlType == 'canvas') {
				canvases.push(cast(loadedControl, Canvas));
			}
		}
	} // LoadControls
	
	private function TranslateControlOptions<T>(options:Dynamic, typeOptions:T):T {
		// make sure the user provided the correct options!
		var fieldNames:Array<String> = Reflect.fields(typeOptions);
		for(mandatoryField in fieldNames) {
			var suppliedValue = Reflect.field(options, mandatoryField);
			if(suppliedValue == null) {
				throw new JSONLoaderException("Control '" + options.name + "' requires a '" + mandatoryField + "' field!");
			}
		}
		
		// inject the options
		TranslateOptions(options, typeOptions);
		
		return typeOptions;
	} // TranslateControlOptions
	
	private function TranslateOptions<T>(options:Dynamic, translatedOptions:T) {
		// loop through all the specified options
		// and set them in the strongly-typed version
		var optionNames:Array<String> = Reflect.fields(options);
		for(optionName in optionNames) {
			var val:Dynamic = Reflect.field(options, optionName);
			
			// deal with special items
			switch(optionName) {
				case 'align': Reflect.setField(translatedOptions, optionName, TranslateTextAlign(val));
				case 'align_vertical': Reflect.setField(translatedOptions, optionName, TranslateTextAlign(val));
				
				case 'onclick': Reflect.setField(translatedOptions, optionName, function(event:MouseEvent, control:Control):Void {
						Luxe.events.fire(val);
					});
				
				case 'onchange': Reflect.setField(translatedOptions, optionName, function(b:Bool, b:Bool):Void {
						Luxe.events.fire(val);
					});
				
				case 'options': {
					var too:Dynamic = {};
					TranslateOptions(options.options, too);
					Reflect.setField(translatedOptions, optionName, too);
				}
				
				// skip the "children" field in this function
				case 'children': continue;
				
				// we only have a single renderer for now anyway
				case 'rendering': {
					if(options.rendering != rendering)
						throw new JSONLoaderException("Defining different rendering isn't supported in JSON loading yet!");
					Reflect.setField(translatedOptions, optionName, val);
				}
				
				default: {
					if(optionName.startsWith("color")) {
						// translate colours
						Reflect.setField(translatedOptions, optionName, new luxe.Color().rgb(Std.parseInt(val)));
					}
					else {
						Reflect.setField(translatedOptions, optionName, val);
					}
				}
			}
		}
	} // TranslateOptions
	
	private function TranslateTextAlign(align:String):mint.types.Types.TextAlign {
		return switch(align) {
			case 'unknown': mint.types.Types.TextAlign.unknown;
			case 'left': mint.types.Types.TextAlign.left;
			case 'right': mint.types.Types.TextAlign.right;
			case 'center': mint.types.Types.TextAlign.left;
			case 'top': mint.types.Types.TextAlign.top;
			case 'bottom': mint.types.Types.TextAlign.bottom;
			default: throw new JSONLoaderException("Unknown text align '" + align + "'!");
		}
	} // TranslateTextAlign
}