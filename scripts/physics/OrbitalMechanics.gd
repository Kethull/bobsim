extends Resource
class_name OrbitalMechanics

# Note: Config is an AutoLoad, so it's globally accessible.

func solve_kepler_equation(M_rad: float, e: float, tolerance: float = 1e-10, max_iterations: int = 100) -> float:
    if e >= 1.0 or e < 0.0:
        printerr("Eccentricity out of bounds: " + str(e) + " for M_rad: " + str(M_rad))
        # Return M_rad or handle error appropriately, e.g., clamp e or return NaN
        # For now, returning M_rad as per original, but this indicates an issue.
        return M_rad

    var E_rad: float # Eccentric Anomaly
    # Initial guess for E
    if e < 0.8:
        E_rad = M_rad + e * sin(M_rad)
    else:
        # More robust initial guess for high eccentricities (e.g., Danby's method or similar)
        # A common simple one:
        E_rad = PI if M_rad > PI / 2.0 else M_rad

    for _i in range(max_iterations):
        var f_E = E_rad - e * sin(E_rad) - M_rad
        var f_prime_E = 1.0 - e * cos(E_rad)

        if abs(f_E) < tolerance:
            return E_rad

        if abs(f_prime_E) < 1e-12: # Avoid division by zero or very small number
            printerr("Kepler solver: f_prime_E is too small. M_rad: %f, e: %f" % [M_rad, e])
            break # Or handle differently

        var delta_E = f_E / f_prime_E
        var E_next = E_rad - delta_E

        # Check for convergence against delta_E as well, or if E_next is significantly different
        if abs(E_next - E_rad) < tolerance and abs(f_E) < tolerance : # Stricter convergence
             return E_next

        E_rad = E_next

    # Fallback if no convergence
    printerr("Kepler solver did not converge. M_rad: %f, e: %f, Last E_rad: %f" % [M_rad, e, E_rad])
    return E_rad # Return the last computed E_rad

func calculate_initial_state_vector(body_data: Dictionary, central_mass_kg: float) -> Dictionary:
    var a_au = body_data.get("semi_major_axis_au", 0.0)
    if a_au == 0.0 and body_data.get("name", "") != "Sun": # Sun is a special case
        # For bodies with a_au = 0 that are not the Sun, this implies they are at the central body's location
        # or their orbit is not defined in this way.
        # This function is typically for orbiting bodies.
        return {
            "position": Vector2.ZERO, # Relative to central body
            "velocity": Vector2.ZERO
        }

    var a_km = a_au * Config.AU_KM
    var mu = Config.GRAVITATIONAL_CONSTANT * central_mass_kg # Standard gravitational parameter (km^3/s^2)

    var M_rad = deg_to_rad(body_data.get("mean_anomaly_at_epoch_deg", 0.0))
    var e = body_data.get("eccentricity", 0.0)

    var E_rad = solve_kepler_equation(M_rad, e)
    
    # True anomaly (nu or f)
    # Using atan2 for quadrant correctness is important.
    # sqrt(1-e^2) * sin(E) / (cos(E)-e) for tan(nu/2) * sqrt((1+e)/(1-e))
    # Or directly:
    var nu_rad: float
    if e < 1.0: # Elliptical/Circular
        nu_rad = 2.0 * atan2(sqrt(1.0 + e) * sin(E_rad / 2.0), sqrt(1.0 - e) * cos(E_rad / 2.0))
    else: # Parabolic or Hyperbolic (not fully handled here, assuming e < 1 from solve_kepler)
        printerr("calculate_initial_state_vector currently assumes elliptical orbits (e < 1). e = " + str(e))
        nu_rad = E_rad # This is incorrect for e >= 1, placeholder

    # Distance to central body (r)
    var r_km = a_km * (1.0 - e * cos(E_rad))
    if r_km < 0: # Should not happen if E_rad is correct for elliptical
        printerr("Calculated r_km is negative: " + str(r_km))
        r_km = abs(r_km)


    # Position in orbital plane (perifocal frame: x towards periapsis, y 90 deg in direction of motion)
    var x_orb_km = r_km * cos(nu_rad)
    var y_orb_km = r_km * sin(nu_rad)

    # Velocity in orbital plane
    # Specific angular momentum h = sqrt(mu * a * (1 - e^2))
    # vr = (mu/h) * e * sin(nu)
    # vt = (mu/h) * (1 + e * cos(nu))
    var vx_orb_km_per_s: float
    var vy_orb_km_per_s: float

    if a_km * (1.0 - e * e) < 0: # p (semi-latus rectum) must be positive
        printerr("Invalid orbital parameters for velocity calculation: a_km=%f, e=%f" % [a_km, e])
        vx_orb_km_per_s = 0.0
        vy_orb_km_per_s = 0.0
    else:
        var p_km = a_km * (1.0 - e * e) # Semi-latus rectum
        var h_km2_per_s = sqrt(mu * p_km) # Specific angular momentum (km^2/s)
        
        if abs(r_km) < 1e-9: # Avoid division by zero if at the center (should not happen for orbiting body)
             vx_orb_km_per_s = 0.0
             vy_orb_km_per_s = 0.0
        else:
            vx_orb_km_per_s = (mu / h_km2_per_s) * (-sin(nu_rad)) # Radial velocity component is (mu/h) * e * sin(nu)
                                                            # Tangential component is (mu/h) * (1 + e*cos(nu))
                                                            # This seems to be a common formulation for vx, vy in perifocal frame
            vy_orb_km_per_s = (mu / h_km2_per_s) * (e + cos(nu_rad))


    # Rotation from orbital plane to ecliptic plane (or simulation plane if inclination is relative to it)
    # w_rad = argument of periapsis
    # Omega_rad = longitude of ascending node
    # i_rad = inclination (not used in 2D if orbits are coplanar, but good for future 3D)
    
    var w_rad = deg_to_rad(body_data.get("argument_of_perihelion_deg", 0.0))
    var Omega_rad = deg_to_rad(body_data.get("longitude_of_ascending_node_deg", 0.0))
    # var i_rad = deg_to_rad(body_data.get("inclination_deg", 0.0)) # For 3D

    # For 2D, inclination is often assumed 0 or handled by how Omega and w are combined.
    # If the simulation plane is the reference plane (e.g., ecliptic),
    # the rotation is around Z-axis by (Omega + w).
    
    var angle_rot = Omega_rad + w_rad # Angle from reference direction (e.g., Vernal Equinox) to periapsis

    var cos_rot = cos(angle_rot)
    var sin_rot = sin(angle_rot)

    var x_sim_km = x_orb_km * cos_rot - y_orb_km * sin_rot
    var y_sim_km = x_orb_km * sin_rot + y_orb_km * cos_rot

    var vx_sim_km_per_s = vx_orb_km_per_s * cos_rot - vy_orb_km_per_s * sin_rot
    var vy_sim_km_per_s = vx_orb_km_per_s * sin_rot + vy_orb_km_per_s * cos_rot
    
    return {
        "position": Vector2(x_sim_km, y_sim_km) * Config.KM_SCALE, # Scaled to simulation units
        "velocity": Vector2(vx_sim_km_per_s, vy_sim_km_per_s) * Config.KM_SCALE # Scaled to sim units/sec
    }


func calculate_gravitational_acceleration(target_body: Node2D, all_bodies: Array) -> Vector2:
    var total_accel_km_s2 = Vector2.ZERO # Accumulate acceleration in km/s^2

    # Ensure target_body has mass_kg property, or get it from a reliable source
    # For this function, target_body's mass is not used, only other_body's mass.

    for other_body_node in all_bodies:
        if not is_instance_valid(other_body_node) or other_body_node == target_body:
            continue
        
        # Assuming other_body_node is a CelestialBody or similar with mass_kg and global_position
        if not other_body_node.has_meta("mass_kg"): # Or check for a specific class
            printerr("Other body %s does not have mass_kg" % other_body_node.name)
            continue

        var other_mass_kg = other_body_node.get_meta("mass_kg", other_body_node.get("mass_kg") if other_body_node.has_method("get") else 0.0)
        if other_mass_kg == 0.0:
            continue

        var r_vec_sim = other_body_node.global_position - target_body.global_position # Vector in sim units
        var r_vec_km = r_vec_sim / Config.KM_SCALE # Convert to km
        
        var dist_sq_km = r_vec_km.length_squared()
        
        if dist_sq_km < 1e-12: # Avoid division by zero if bodies are too close (or at same spot)
            continue
            
        var dist_km = sqrt(dist_sq_km)
        
        # Gravitational acceleration: a = G * M_other / r^2, directed towards M_other
        var accel_magnitude_km_s2 = Config.GRAVITATIONAL_CONSTANT * other_mass_kg / dist_sq_km
        var direction_vec_km = r_vec_km / dist_km # Normalized direction vector
        
        total_accel_km_s2 += direction_vec_km * accel_magnitude_km_s2
        
    return total_accel_km_s2 * Config.KM_SCALE # Convert final acceleration to sim_units/s^2

# Verlet integration for a list of bodies (e.g., CelestialBody instances)
# Assumes bodies have: global_position, velocity (sim_units/step), previous_acceleration (sim_units/step^2), mass_kg
# and a method add_to_orbit_path(pos: Vector2)
func propagate_orbits_verlet(bodies: Array, dt_seconds: float):
    if bodies.is_empty():
        return

    var new_positions = {} # Store as Dictionary[Node, Vector2]
    var new_accelerations = {} # Store as Dictionary[Node, Vector2]

    # Step 1: Calculate new positions based on current velocity and previous_acceleration
    # x(t+dt) = x(t) + v(t)*dt + 0.5*a(t)*dt^2
    # Velocity here is v_sim_units_per_physics_step. dt_seconds is the duration of that step.
    # If body.velocity is in sim_units/second, then it's fine.
    # If body.velocity is sim_units/step, and dt_seconds is the time for that step,
    # then v(t)*dt_seconds is not v*dt, it's v_per_step * 1_step.
    # Let's assume body.velocity is in sim_units/second for clarity with dt_seconds.
    # And body.previous_acceleration is in sim_units/second^2.

    for body in bodies:
        if not is_instance_valid(body): continue
        # Ensure body has velocity and previous_acceleration properties
        var current_vel_sim_s = body.get("velocity", Vector2.ZERO) # sim_units/s
        var prev_accel_sim_s2 = body.get("previous_acceleration", Vector2.ZERO) # sim_units/s^2
        
        var pos_change_due_to_vel = current_vel_sim_s * dt_seconds
        var pos_change_due_to_accel = 0.5 * prev_accel_sim_s2 * (dt_seconds * dt_seconds)
        
        new_positions[body] = body.global_position + pos_change_due_to_vel + pos_change_due_to_accel

    # Temporarily update all bodies' global_positions to new_positions to calculate new accelerations
    var original_positions = {}
    for body in bodies:
        if not is_instance_valid(body): continue
        original_positions[body] = body.global_position
        body.global_position = new_positions[body]

    # Step 2: Calculate accelerations a(t+dt) at the new positions
    for body in bodies:
        if not is_instance_valid(body): continue
        # The 'influencing_bodies' should be all other bodies in the 'bodies' array.
        var influencing_bodies = []
        for b_other in bodies:
            if is_instance_valid(b_other) and b_other != body:
                influencing_bodies.append(b_other)
        
        new_accelerations[body] = calculate_gravitational_acceleration(body, influencing_bodies) # This returns sim_units/s^2

    # Restore original positions before calculating new velocities
    for body in bodies:
        if not is_instance_valid(body): continue
        body.global_position = original_positions[body]

    # Step 3: Calculate new velocities and finalize positions
    # v(t+dt) = v(t) + 0.5 * (a(t) + a(t+dt)) * dt
    for body in bodies:
        if not is_instance_valid(body): continue
        var prev_accel_sim_s2 = body.get("previous_acceleration", Vector2.ZERO) # a(t)
        var current_accel_sim_s2 = new_accelerations[body] # a(t+dt)
        
        var avg_accel_sim_s2 = 0.5 * (prev_accel_sim_s2 + current_accel_sim_s2)
        
        var current_vel_sim_s = body.get("velocity", Vector2.ZERO)
        var new_vel_sim_s = current_vel_sim_s + avg_accel_sim_s2 * dt_seconds
        
        body.set("velocity", new_vel_sim_s)
        body.global_position = new_positions[body] # This was x(t+dt)
        body.set("previous_acceleration", current_accel_sim_s2) # Store for next step
        
        if body.has_method("add_to_orbit_path"):
            body.add_to_orbit_path(body.global_position)