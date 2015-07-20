import luxe.Color;
import luxe.Vector;
import luxe.Input;
import luxe.Text;

import mint.Canvas;
import mint.loaders.JSONLoader;
import mint.loaders.JSONLoader.JSONLoaderException;
import mint.render.Rendering;
import mint.types.Types;
import mint.Control;
import mint.render.luxe.Convert;

import mint.layout.margins.Margins;

class Main extends luxe.Game {
    var uiLoader:JSONLoader = new JSONLoader();

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

        // load the UI
        try {
            uiLoader.FromJSONObject(Luxe.resources.json('assets/UI.json').asset.json);
        }
        catch(exception:JSONLoaderException) {
            trace("ERROR: " + exception.message);
        }
    } // ready

    override function onmousemove(e) {
        for(canvas in uiLoader.canvases) canvas.mousemove(Convert.mouse_event(e));
    } // onmousemove

    override function onmousewheel(e) {
       for(canvas in uiLoader.canvases) canvas.mousewheel(Convert.mouse_event(e));
    } // onmousewheel

    override function onmouseup(e) {
       for(canvas in uiLoader.canvases) canvas.mouseup(Convert.mouse_event(e));
    } // onmouseup

    override function onmousedown(e) {
       for(canvas in uiLoader.canvases) canvas.mousedown(Convert.mouse_event(e));
    } // onmousedown

    override function onkeydown(e:luxe.Input.KeyEvent) {
       for(canvas in uiLoader.canvases) canvas.keydown(Convert.key_event(e));
    } // onkeydown

    override function ontextinput(e:luxe.Input.TextEvent) {
       for(canvas in uiLoader.canvases) canvas.textinput(Convert.text_event(e));
    } // ontextinput

    override function onkeyup(e:luxe.Input.KeyEvent) {
       for(canvas in uiLoader.canvases) canvas.keyup(Convert.key_event(e));
    } // onkeyup

    override function onrender() {
       for(canvas in uiLoader.canvases) canvas.render();
    } // onrender

    override function update(dt:Float) {
       for(canvas in uiLoader.canvases) canvas.update(dt);
    } // update
} //Main