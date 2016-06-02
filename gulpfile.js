var gulp = require('gulp');
var coffee = require('gulp-coffee');
var gutil = require('gulp-util');
var closureCompiler = require('gulp-closure-compiler');

function compile() {
  return gulp.src('./lib/*.coffee')
    .once('data', function() {gutil.log('Compile: start');})
    .once('end', function() {gutil.log('Compile: finish');})
    .pipe(coffee({ bare: true }).on('error', gutil.log))
    .pipe(gulp.dest('dist'))
    .pipe(closureCompiler({
      compilerPath: 'bower_components/closure-compiler/compiler.jar',
      fileName: 'oms.min.js',
      compilerFlags: {
        compilation_level: 'ADVANCED_OPTIMIZATIONS',
        externs: [
          'bower_components/google-maps-externs/google_maps_api.js'
        ],
        output_wrapper: '(function(){%output%})();',
        warning_level: 'QUIET'
      }
    }))
    .pipe(gulp.dest('dist'));
}

gulp.task('default', function () {
  gulp.watch('./lib/*.coffee', compile);
  compile();
});

gulp.task('build', compile);