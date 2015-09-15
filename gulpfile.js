var gulp = require('gulp');
var concat = require('gulp-concat-util');
var indent = require('gulp-indent');
var wrap = require('gulp-wrap');
var jshint = require('gulp-jshint');

var del = require('del');


gulp.task('jshint:src', function() {

  return gulp.src('src/*.js')

    .pipe(jshint())
    .pipe(jshint.reporter('default'))
});


gulp.task('clean:dist', function () {

  return del('dist/*');
});


gulp.task('copy:shaders', ['clean:dist'], function() {

  return gulp.src('src/shaders/*')
    .pipe(gulp.dest('dist/shaders/'));
});


gulp.task('concat:dist', ['clean:dist'], function() {

  return gulp.src([

    'src/js/PrimitiveType.js',
    'src/js/PathTracer.js',
    'src/js/index.js'
  ])

    .pipe(concat('pathtracer.js', {

      process: function (src) {

        var i = src.indexOf('*/');
        return src.slice(i + 2).trim() + '\n';
      }
    }))

    .pipe(gulp.dest('dist'));
});


gulp.task('wrap:dist', ['concat:dist'], function() {

  return gulp.src('dist/pathtracer.js')

    .pipe(indent({

      tabs: false,
      amount: 2
    }))

    .pipe(wrap(

      '/**\n' +
      ' * @author Raoul Harel\n' +
      ' * @license The MIT license (LICENSE.txt)\n' +
      ' * @copyright 2015 Raoul Harel\n' +
      ' * @url https://github.com/rharel/webgl-pathtracer\n' +
      ' */\n' +
      '\n\n' +
      '(function () {\n\n' +
      '<%= contents %>\n' +
      '})();\n'
    ))

    .pipe(gulp.dest('dist'));
});


gulp.task('build', ['wrap:dist', 'copy:shaders']);


gulp.task('default', ['build']);