shader_type canvas_item;

// Screen texture uniform for Godot 4.x
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// CRT effect parameters
uniform float screen_curvature : hint_range(0.0, 10.0) = 3.0; // Controls fisheye/barrel distortion amount
uniform float corner_darkness : hint_range(0.0, 1.0) = 0.35; // Controls vignette effect
uniform float vignette_size : hint_range(0.0, 1.0) = 0.8; // Size of the vignette
uniform vec2 screen_size = vec2(320.0, 240.0); // Simulated screen resolution
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.15; // Intensity of scanlines
uniform float noise_strength : hint_range(0.0, 1.0) = 0.07; // Amount of static noise
uniform vec4 tint_color : source_color = vec4(0.8, 0.9, 1.0, 1.0); // Slight blue tint typical of CRTs
uniform bool rgb_shift = true; // RGB color channel shifting
uniform float rgb_shift_amount : hint_range(0.0, 5.0) = 0.5; // Amount of RGB shifting
uniform float edge_blur : hint_range(0.0, 0.2) = 0.05; // Amount of blur for the edges
uniform float edge_gradient : hint_range(0.0, 0.5) = 0.15; // Width of the gradient around edges
uniform bool full_screen_scanlines = true; // Apply scanlines to the entire screen

// Random function for noise generation
float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Distortion function for CRT curvature
vec2 apply_curvature(vec2 uv, float curvature) {
    // Convert UV from 0-1 range to -1 to 1 range
    vec2 curved_uv = uv * 2.0 - 1.0;
    
    // Apply barrel distortion
    float r2 = curved_uv.x * curved_uv.x + curved_uv.y * curved_uv.y;
    curved_uv *= 1.0 + r2 * curvature;
    
    // Convert back to 0-1 range
    return (curved_uv * 0.5 + 0.5);
}

// Apply scanlines separate from other effects
float apply_scanlines(vec2 uv, float strength) {
    float scanline = sin(uv.y * screen_size.y * PI) * 0.5 + 0.5;
    return strength * scanline;
}

void fragment() {
    // Apply screen curvature (fisheye/barrel distortion)
    vec2 curved_uv = apply_curvature(SCREEN_UV, screen_curvature * 0.03);
    
    // Calculate how far the curved UV is from the valid range
    float x_dist = 0.0;
    float y_dist = 0.0;
    
    if (curved_uv.x < 0.0) x_dist = -curved_uv.x;
    else if (curved_uv.x > 1.0) x_dist = curved_uv.x - 1.0;
    
    if (curved_uv.y < 0.0) y_dist = -curved_uv.y;
    else if (curved_uv.y > 1.0) y_dist = curved_uv.y - 1.0;
    
    float edge_dist = max(x_dist, y_dist);
    
    // Apply scanlines to the entire screen
    float scanline_effect = 0.0;
    if (full_screen_scanlines) {
        scanline_effect = apply_scanlines(SCREEN_UV, scanline_strength);
    }
    
    // Initialize output color
    vec4 color;
    
    // Check if we're within the valid texture boundaries
    bool in_valid_area = (curved_uv.x >= 0.0 && curved_uv.x <= 1.0 && curved_uv.y >= 0.0 && curved_uv.y <= 1.0);
    
    if (in_valid_area) {
        // We're in the valid display area
        
        // Create RGB shift effect
        if (rgb_shift) {
            float shift_amount = rgb_shift_amount * 0.001;
            
            // Slightly shift red channel left/up
            float red = texture(screen_texture, clamp(curved_uv - vec2(shift_amount, shift_amount), vec2(0.0), vec2(1.0))).r;
            
            // Keep green channel at center
            float green = texture(screen_texture, curved_uv).g;
            
            // Slightly shift blue channel right/down
            float blue = texture(screen_texture, clamp(curved_uv + vec2(shift_amount, shift_amount), vec2(0.0), vec2(1.0))).b;
            
            // Combine channels
            color = vec4(red, green, blue, texture(screen_texture, curved_uv).a);
        } else {
            color = texture(screen_texture, curved_uv);
        }
        
        // Apply scanlines only to the curved area if not using full screen scanlines
        if (!full_screen_scanlines) {
            scanline_effect = apply_scanlines(curved_uv, scanline_strength);
        }
        
        // Apply scanlines
        color.rgb -= scanline_effect;
        
        // Apply static noise only to the actual image area
        float noise = random(curved_uv + TIME * 0.01) * noise_strength;
        color.rgb += vec3(noise);
        
        // Apply vignette (corner darkening)
        float vignette = length(SCREEN_UV - 0.5) * vignette_size;
        vignette = clamp(vignette, 0.0, 1.0);
        color.rgb *= 1.0 - vignette * corner_darkness;
        
        // Apply slight CRT tint
        color.rgb *= tint_color.rgb;
        
        // Apply inner gradient that darkens as we approach the edge of the valid area
        // This creates a smoother transition at the edges
        float inner_gradient = 0.0;
        if (edge_gradient > 0.0) {
            // Calculate distance from edge
            float dist_from_edge_x = min(curved_uv.x, 1.0 - curved_uv.x);
            float dist_from_edge_y = min(curved_uv.y, 1.0 - curved_uv.y);
            float dist_from_edge = min(dist_from_edge_x, dist_from_edge_y);
            
            // Create a gradient that increases as we get closer to the edge
            inner_gradient = 1.0 - smoothstep(0.0, edge_gradient, dist_from_edge);
            
            // Darken the image near the edges
            color.rgb = mix(color.rgb, vec3(0.0), inner_gradient * 0.7);
        }
    } else {
        // We're outside the valid display area - create a blurred edge
        
        // Start with a black pixel
        color = vec4(0.0, 0.0, 0.0, 1.0);
        
        // Apply scanlines to the black areas if enabled
        if (full_screen_scanlines) {
            color.rgb -= scanline_effect;
        }
        
        // Only apply blur within the blur distance
        if (edge_dist < edge_blur) {
            // Calculate blur factor (1.0 = use distorted image, 0.0 = use black)
            float blur_factor = 1.0 - smoothstep(0.0, edge_blur, edge_dist);
            
            // Sample the nearest valid pixel on the screen
            vec2 safe_uv = clamp(curved_uv, vec2(0.0), vec2(1.0));
            vec4 edge_sample = texture(screen_texture, safe_uv);
            
            // Apply a darkening gradient to the sampled pixel
            edge_sample.rgb *= 0.3; // Darken the edge sample
            
            // Mix between black and the darkened edge sample based on blur factor
            color = mix(color, edge_sample, blur_factor * 0.7);
            
            // Apply scanlines to the mixed result
            if (full_screen_scanlines) {
                color.rgb -= scanline_effect;
            }
        }
    }
    
    // Add a subtle gradient glow extending beyond the edge
    if (!in_valid_area && edge_dist < edge_gradient) {
        // Calculate a secondary gradient for the outer glow
        float glow_factor = 1.0 - smoothstep(0.0, edge_gradient, edge_dist);
        
        // Sample the nearest valid pixel
        vec2 safe_uv = clamp(curved_uv, vec2(0.0), vec2(1.0));
        vec4 glow_sample = texture(screen_texture, safe_uv);
        
        // Create a very dark version of the pixel for the glow
        vec3 glow_color = glow_sample.rgb * 0.15;
        
        // Apply the glow
        color.rgb = mix(color.rgb, glow_color, glow_factor * 0.4);
    }
    
    COLOR = color;
}