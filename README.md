## What is this?
A simple pathtracer implementation that runs entirely on the GPU. View the [live demo here](http://rharel.github.io/webgl-pathtracer/) (your browser needs to support WebGL and the OES_texture_float extension).

Features:
 * Materials
   * Lambert
   * Mirror
 * Geometries 
   * Sphere
   * Plane
 * Lights
   * Sphere
 * Grid stratification
 * Early ray termination with russian-roulette 

## Installation

Install via bower: `bower install rharel/webgl-pathtracer`

The `dist/` directory contains both a normal (`glpt.js`) as well as a minified version of the library (`glpt.min.js`).
Include in the browser using `<script src="path/to/glpt.min.js"></script>`


## Usage

### Setting up the scene

Before we can render anything, we need to setup the scene to be rendered. This requires us to specify three things: 1. The type of materials present, 2. the scene's geometry, and 3. light sources.

Suppose our scene consists of a blue sphere on a mirror plane. 

Let's start with the materials:
```javascript
var materials = [
    
	{
		type: GLPT.Material.Lambert,
		color: new THREE.Color('red')
	},
    {
    	type: GLPT.Material.Mirror
    }
];
```

We list our materials in an object array. Each material descriptor must declare its type from the `GLPT.Material` enumeration. Each material type has different options associated with it. As you can see, the Lambertian material has an additional color parameter while the mirror material does not.

Next, we need to declare our scene's geometry:
```javascript
var geometry = [

	{
    	shape: {

        	type: GLPT.Primitive.Sphere,
        	position: {x: 0, y: 1, z: 0},
        	radius: 1
        },
      	material_index: 0
    },
	{
    	shape: {

        	type: GLPT.Primitive.Plane,
        	position: {x: 0, y: 0, z: 0},
        	normal: {x: 0, y: 1, z: 0}
        },
      	material_index: 1
    }
];
```

Again, we list the scene's geometries in an object array. Each object has the form `{shape:, material_index:}`. The shape descriptor must have a `type:` declared that is a value of the `GLPT.Primitive` enumeration. Much like materials, different primitive types have different additional options associated with them. In this example we see position and radius as options for the sphere, and position and normal for the plane. 

The `material_index:` of each object is an integer that refers to a material in our previously defined materials list by its index. This is the material that will be used to render the relevant geometry.

Finally, we should list all the light-source in our scene, like so:
```javascript
var lighting = [

	{
        type: GLPT.Light.Sphere,
        position: {x: 0.0, y: 0.75, z: 0.0},
        radius: 0.25,
        color: {r: 1, g: 1, b: 1},
        intensity: 6
    }
];
```

Once again, each light object we list must declare its type from the `GLPT.Light` enumeration. Each type will carry additional parameters with it, such as position and radius for sphere light. The color and intensity parameters are common to all light types.

Now that we have our scene specified, let's setup our tracer.

### Setting up the tracer

```javascript
var tracer = new GLPT.Tracer({

    resolution: {x: 512, y: 512},
    pixel_sampler: {

        stratifier: GLPT.Stratifier.Grid,
        degree: 2
    }
});
```

We intialize our tracer with our canvas' resolution and also specify our stratifier's parameters. The grid stratifier takes a single paramter, `degree`, which indicates how many times a pixel is subdivided during stratification.

```javascript
var scene = {materials: materials, geometry: geometry, lighting: lighting};
tracer.scene = scene;
tracer.camera.position.set(0, 0, 3);
tracer.camera.rotation.set(0, 0, 0);
tracer.camera.fov = 75;
```

Here we aggregate our scene description listing into one object of the form `{materials:, geometry:, lighting:}` and deliver it to our tracer. We can also take this opportunity to tweak the camera's  properties if we wish (the camera is a regular threejs [PerspectiveCamera](http://threejs.org/docs/#Reference/Cameras/PerspectiveCamera)).

```javascript
tracer.update();
```

Finally, we call `update()` to initialize our tracer with the given scene and camera information we fed it.

### Rendering

```javascript
var renderer = new THREE.WebGLRenderer({

	canvas: document.getElementById('render-target')
});
tracer.render(renderer);
```

That's it! All we had to do now is create a threejs Renderer pointing to our desired canvas, and render our scene to it!

### Composing an image

With path-tracers, a single render call produces a noisy image since there is a deal of randomness involved in the rays' path. To achieve a smooth image such as that in the demo, we will need to average many render calls together. We support this with a Composer class:

```javascript
var composer = new GLPT.Composer({resolution: {x: <width>, y: <height>}});
```

Initialize the composer to the same resolution as our canvas, and then have it process every render call you make through the tracer:

```javascript
tracer.render(renderer, composer.target);
composer.process(renderer);
```

As you probably have noticed, the call to `render()` now takes an additional paramter - a render target. This causes the result of the tracing to be stored in a buffer inside our composer. The composer then adds this buffer to all previously recorded tracings and averages the result through a call to `process()`. The end-product is a [nice smooth image](http://rharel.github.io/webgl-pathtracer/).

## License

This software is licensed under the **MIT License**. See the [LICENSE](LICENSE.txt) file for more information.
