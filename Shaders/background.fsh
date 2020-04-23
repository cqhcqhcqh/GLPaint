
uniform sampler2D texture0;
uniform sampler2D texture1;
varying lowp vec4 textureVertex;

void main() {
    gl_FragColor = mix(texture2D(texture0, textureVertex.xy), texture2D(texture1, textureVertex.xy), 0.5);
}
