uniform vec2 windowCenter;
uniform vec2 windowHalfSize;
uniform float borderThickness;
uniform float radius;
uniform vec4 color;

in vec2 v_pixel;
out vec4 fragColor;

float sdRoundBox(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main()
{
    vec2 p = v_pixel - windowCenter;

    float outerRadius = radius + borderThickness;
    float dOuter = sdRoundBox(p, windowHalfSize + vec2(borderThickness), outerRadius);
    float dInner = sdRoundBox(p, windowHalfSize, radius);

    // Signed distance to the ring: outside the inner box and inside the
    // outer one. A single centered AA band keeps the ring interior at full
    // opacity even at 1 device pixel thick. Two independent smoothsteps
    // would overlap there and smear the ring into 2px of half alpha.
    float dRing = max(-dInner, dOuter);
    float a = clamp(0.5 - dRing, 0.0, 1.0);

    fragColor = vec4(color.rgb, color.a * a);
}
