import luxe.Color;
import luxe.Vector;
import luxe.Input;
import luxe.Text;

import mint.Canvas;
import mint.loaders.JSONLoader;
import mint.render.luxe.LuxeMintRender;
import mint.render.Rendering;
import mint.types.Types;
import mint.Control;
import mint.render.luxe.Convert;

import mint.layout.margins.Margins;

class Main extends luxe.Game {
    var rendering:LuxeMintRender;
    var layout:Margins;
    var canvas:Canvas;
    
    var controls:Array<Control>;

    override function config(config:luxe.AppConfig) {
        // load the images
        config.preload.textures.push({ id:'assets/960.png' });
        config.preload.textures.push({ id:'assets/transparency.png' });
        config.preload.textures.push({ id:'assets/mint.box.png' });
        
        // also the UI layout
        config.preload.jsons.push({ id: 'assets/UI.json' });
        return config;
    } // config

    override function ready() {
        // set up the background
        Luxe.renderer.clear_color.rgb(0x161619);
        new luxe.Sprite({ texture:Luxe.resources.texture('assets/960.png'), centered: false, depth: -1 });
        
        // set up mint
        rendering = new LuxeMintRender();
        layout = new Margins();
        
        // create a canvas
        canvas = new Canvas({
            x: 0, y: 0, w: 960, h: 640,
            rendering: rendering
        });

        // load a UI into the canvas
        controls = JSONLoader.Load(Luxe.resources.json('assets/UI.json').asset.json, canvas,
                                   function(name:String, type:String, field:String):Dynamic {
                                        throw "Error! " + name + " (" + type + ") is missing field '" + field + "'!";
                                        return null;
                                   },
                                   function(c:Control, m:String):Void {
                                        trace(m);
                                   });
        
    } // ready

    override function onmousemove(e) {
        if(canvas != null) canvas.mousemove(Convert.mouse_event(e));
    } // onmousemove

    override function onmousewheel(e) {
       if(canvas != null) canvas.mousewheel(Convert.mouse_event(e));
    } // onmousewheel

    override function onmouseup(e) {
       if(canvas != null) canvas.mouseup(Convert.mouse_event(e));
    } // onmouseup

    override function onmousedown(e) {
       if(canvas != null) canvas.mousedown(Convert.mouse_event(e));
    } // onmousedown

    override function onkeydown(e:luxe.Input.KeyEvent) {
       if(canvas != null) canvas.keydown(Convert.key_event(e));
    } // onkeydown

    override function ontextinput(e:luxe.Input.TextEvent) {
       if(canvas != null) canvas.textinput(Convert.text_event(e));
    } // ontextinput

    override function onkeyup(e:luxe.Input.KeyEvent) {
       if(canvas != null) canvas.keyup(Convert.key_event(e));
    } // onkeyup

    override function onrender() {
       if(canvas != null) canvas.render();
    } // onrender

    override function update(dt:Float) {
       if(canvas != null) canvas.update(dt);
    } // update
} //Main