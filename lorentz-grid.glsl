#define GRID_SPACING 2.0 // Spacing between grid lines in transformed (primed) space
#define RAPIDITY_SPEED 0.3 // oscillating Lorentz Boost spd
#define COLOR_SHIFT_MAG 2.0 // time dialiation color effect multipler
#define LINE_THICKNESS 0.05 // Thickness of the grid lines (for defining line intersection width)
#define FAR_DISTANCE 1e7 // A large number used for initializing minimum distance (t)
// 4x4 Lorentz Boost Matrix (Boost along the X-axis)
// some MATH stuff: The Lorentz transformation relates the coordinates (t, x, y, z) in one
// inertial frame to the coordinates (t', x', y', z') in a frame moving at velocity v
// along the X-axis. The matrix is typically defined using the rapidity phi
// (where tanh(phi) = v/c).
// This matrix only transforms the time (t) and the axis of motion (x).
mat4 lorentzBoostMatrix(float phi) {
    float ch = cosh(phi); // cosh (represents the Gamma factor, or time dilation)
    float sh = sinh(phi); // sinh sine (related to Gamma * v/c)

    // The 4x4 Lorentz matrix Λ is defined as:
    // [ ch, -sh, 0, 0 ]  <- Transforms t (time)
    // [ -sh, ch, 0, 0 ]  <- Transforms x (space-x)
    // [ 0, 0, 1, 0 ]     <- y is unchanged
    // [ 0, 0, 0, 1 ]     <- z is unchanged
    return mat4(
        ch, -sh, 0.0, 0.0,
        -sh, ch, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0
    );
}
// the ACTUAL logic: this function finds the smallest positive ray parameter 't' that
// intersects a transformed grid line. A grid line is the intersection of two
// transformed planes (e.g., x'=n and y'=m).
// ro is ray orgin and rd is ray direction
// There's a series of steps we have to follow.
float intersectTransformedGrid(vec3 ro, vec3 rd, float phi, out vec3 hit_normal) {
    // 1. We gotta apply transformation to ray
    mat4 Lambda = lorentzBoostMatrix(phi);
    float min_t = FAR_DISTANCE;

    // A 4D space-time point X(t) on the ray is (t_observer, ro + t * rd).
    // We set the observer's local time t_observer to 0 for the ray origin (ro).
    vec4 ro4 = vec4(0.0, ro);
    vec4 rd4 = vec4(1.0, rd); // Temporal component of 1 = time advances with ray distance

    // The transformed ray is X'(t) = Λ * (ro4 + t * rd4)
    // By linearity, X'(t) = (Λ * ro4) + t * (Λ * rd4) = B_prime + t * A_prime
    vec4 B_prime = Lambda * ro4; // Λ * ro4 is the transformed ray origin
    vec4 A_prime = Lambda * rd4; // Λ * rd4 is the transformed ray direction

    // The transformed coordinate X'[i] is now: A_prime[i] * t + B_prime[i]

    // 2. solve these plane intersections

    // we loop over the 3 spatial axes (1=x', 2=y', 3=z')
    for (int axis = 1; axis <= 3; axis++) {
        float A_comp = A_prime[axis]; // Transformed direction component
        float B_comp = B_prime[axis]; // Transformed origin component

        if (abs(A_comp) < 0.0001) continue; // Skip if ray is parallel to this transformed axis

        // Loop over nearby integer grid planes (n * G)
        for (int n_int = -5; n_int <= 5; n_int++) {
            float target_val = float(n_int) * GRID_SPACING;

            // More math: Solve the linear equation for t:
            // A_comp * t + B_comp = target_val
            float t = (target_val - B_comp) / A_comp;

            // Check if t is positive (in front of the camera) and closer than min_t
            if (t > 0.001 && t < min_t) {

                // 3. Line Intersection Check (Hitting an intersection of two planes)
                // which... basically is a grid line

                // Determine the 3D world hit position
                vec3 p_hit = ro + rd * t;
                vec4 p_hit4 = vec4(t, p_hit);
                vec4 p_prime = Lambda * p_hit4; // Get the transformed coordinates at the hit point

                // We only register a hit if this intersection point is close to a grid line
                // in the other two spatial dimensions (this forms the grid lines).

                // Get indices for the other two spatial axes
                int axis_other_1 = (axis % 3) + 1;
                int axis_other_2 = ((axis + 1) % 3) + 1;

                // Calculate distance to the center of the closest grid line for the other axes
                float dist_other_1 = abs(mod(p_prime[axis_other_1] + 0.5 * GRID_SPACING, GRID_SPACING) - 0.5 * GRID_SPACING);
                float dist_other_2 = abs(mod(p_prime[axis_other_2] + 0.5 * GRID_SPACING, GRID_SPACING) - 0.5 * GRID_SPACING);

                if (dist_other_1 < LINE_THICKNESS || dist_other_2 < LINE_THICKNESS) {
                    min_t = t;
                    // Define the normal based on the *original* normal of the plane we hit
                    if (axis == 1) hit_normal = normalize(vec3(A_comp, 0.0, 0.0));
                    else if (axis == 2) hit_normal = normalize(vec3(0.0, A_comp, 0.0));
                    else hit_normal = normalize(vec3(0.0, 0.0, A_comp));
                }
            }
        }
    }

    return min_t;
}
void mainImage(out vec4 fragColor, in vec2 fragCoord ) {
    // Convert pixel coordinates to normalized screen space [-1, 1]
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    // 1. Camera setup stuff

    float cam_dist = 6.0;
    float cam_height = 1.0;
    float orbit_speed = 0.2;

    // Ray Origin (ro): The 3D position of the camera in world space.
    // Here, the camera orbits around the center (0,0,0) over time (iTime).
    vec3 ro = cam_dist * vec3(cos(iTime * orbit_speed), cam_height, sin(iTime * orbit_speed));

    vec3 target = vec3(0.0); // The point the camera is looking at (the center of the grid)

    // Camera Coordinate System (Orthonormal Basis):

    // ww (Forward/Look Vector): The Z-axis of the camera, pointing from ro to target.
    vec3 ww = normalize(target - ro);

    // uu (Right Vector): The X-axis of the camera, orthogonal to the up vector (0,1,0) and ww.
    vec3 uu = normalize(cross(vec3(0.0, 1.0, 0.0), ww));

    // vv (Up Vector): The Y-axis of the camera, completing the right-handed basis.
    vec3 vv = normalize(cross(ww, uu));
    // Ray Direction (rd): The direction vector of the ray cast from the camera through the pixel (uv).
    // The FoV (Field of View) is determined by the scalar multiplying ww.
    vec3 rd = normalize(uv.x * uu + uv.y * vv + .8 * ww);
    // 2. Lorentz Boost Parameter

    int setting = 0;
    float phi = 0.0;

    if(setting == 0){

    // The rapidity (phi) oscillates over time to show the relativistic effects clearly
    // this is irrelevant to the camera orbiting
     phi = sin(iTime * RAPIDITY_SPEED) * 1.5;

    }else{
    // The camera orbits at X = cos(t). The velocity in X is the derivative: -sin(t).
    // When the camera moves parallel to the X-axis (at the top/bottom of the orbit), the relativistic
    // contraction should be strongest
     phi = atanh(-sin(iTime * orbit_speed) * 0.99);
    }
    // 3. Ray Tracing
    vec3 N = vec3(0.0); // Normal vector (output from intersection)
    float t = intersectTransformedGrid(ro, rd, phi, N); // The analytical solution returns distance 't'

    // 4. Shading thru Phong
    vec3 final_color = vec3(0.0);
    vec3 background_color = vec3(0.01, 0.01, 0.03);

    if (t < FAR_DISTANCE) {
        // We have a hit. Calculate illumination using Phong model.

        vec3 p = ro + rd * t; // The 3D hit point in world space
        vec3 L = normalize(vec3(1.0, 1.0, -1.0)); // Light direction
        vec3 V = -rd; // View direction

        // a kind-of relativistic collor Effect: Color shift/brightness increase based on boost magnitude (phi)
        float speed_effect = abs(phi) * COLOR_SHIFT_MAG;

        // material properties
        vec3 base_color = vec3(0.2, 0.6, 1.0);
        float shininess = 64.0;
        // ambient
        vec3 ambient = 0.3 * base_color * (1.0 + speed_effect);

        // diffuse thru lambertian
        float diff = max(0.0, dot(N, L));
        vec3 diffuse = diff * base_color * 1.5;

        // specular
        vec3 R = reflect(-L, N);
        float spec = pow(max(0.0, dot(R, V)), shininess);
        vec3 specular = spec * vec3(2.0);

        // actual shading
        final_color = ambient + diffuse + specular;

        // fogginess
        float fog = 1. / (1.0 + t * 0.05);
        final_color *= fog;

    } else {
        // No hit
        final_color = background_color;
    }
    fragColor = vec4(final_color, 1.0);
}
