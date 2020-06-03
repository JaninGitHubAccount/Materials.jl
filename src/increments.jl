# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/Materials.jl/blob/master/LICENSE

"""
    uniaxial_increment!(material, dstrain11, dt;
                        dstrain=[dstrain11, -0.3*dstrain11, -0.3*dstrain11, 0.0, 0.0, 0.0],
                        max_iter=50, norm_acc=1e-9)

Find a compatible strain increment for `material`.

The material state (`material.variables`) and the component 11 of the *strain*
increment are taken as prescribed. This routine computes the other components of
the strain increment such that the stress state predicted by integrating the
material for one timestep matches the stress state stored in
`materials.variables.stress`. The computation starts from the initial guess
`dstrain`.

To converge quickly, the update takes advantage of the jacobian ∂σij/∂εkl
(`material.variables_new.jacobian`) provided by the material implementation.

This process is iterated at most `max_iter` times, until the non-prescribed
components of `dstrain` converge to within `norm_acc` (in a vector norm
sense).

If `max_iter` is reached and `dstrain` has not converged, `ErrorException` is
thrown.

Note the timestep is **not** committed; we call `integrate_material!`, but not
`update_material!`. Only `material.variables_new` is updated.
"""
function uniaxial_increment!(material, dstrain11, dt;
                             dstrain=[dstrain11, -0.3*dstrain11, -0.3*dstrain11, 0.0, 0.0, 0.0],
                             max_iter=50, norm_acc=1e-9)
    converged = false
    stress0 = tovoigt(material.variables.stress)
    for i=1:max_iter
        material.ddrivers.time = dt
        material.ddrivers.strain = fromvoigt(Symm2{Float64}, dstrain; offdiagscale=2.0)
        integrate_material!(material)
        stress = tovoigt(material.variables_new.stress)
        dstress = stress - stress0
        D = tovoigt(material.variables_new.jacobian)
        dstr = -D[2:end,2:end] \ dstress[2:end]
        dstrain[2:end] .+= dstr
        if norm(dstr) < norm_acc
            converged = true
            break
        end
    end
    converged || error("No convergence in strain increment")
    return nothing
end

"""
    biaxial_increment!(material, dstrain11, dstrain12, dt;
                       dstrain=[dstrain11, -0.3*dstrain11, -0.3*dstrain11, 0, 0, dstrain12],
                       max_iter=50, norm_acc=1e-9)

Find a compatible strain increment for `material`.

The material state (`material.variables`) and the components 11 and 12 of the
*strain* increment are taken as prescribed. This routine computes the other
components of the strain increment such that the stress state predicted by
integrating the material for one timestep matches the stress state stored in
`materials.variables.stress`. The computation starts from the initial guess
`dstrain`.

To converge quickly, the update takes advantage of the jacobian ∂σij/∂εkl
(`material.variables_new.jacobian`) provided by the material implementation.

This process is iterated at most `max_iter` times, until the non-prescribed
components of `dstrain` converge to within `norm_acc` (in a vector norm
sense).

If `max_iter` is reached and `dstrain` has not converged, `ErrorException` is
thrown.

Note the timestep is **not** committed; we call `integrate_material!`, but not
`update_material!`. Only `material.variables_new` is updated.
"""
function biaxial_increment!(material, dstrain11, dstrain12, dt;
                            dstrain=[dstrain11, -0.3*dstrain11, -0.3*dstrain11, 0, 0, dstrain12],
                            max_iter=50, norm_acc=1e-9)
    converged = false
    stress0 = tovoigt(material.variables.stress)  # observed
    for i=1:max_iter
        material.ddrivers.time = dt
        material.ddrivers.strain = fromvoigt(Symm2{Float64}, dstrain; offdiagscale=2.0)
        integrate_material!(material)
        stress = tovoigt(material.variables_new.stress)  # predicted
        dstress = stress - stress0
        D = tovoigt(material.variables_new.jacobian)
        dstr = -D[2:end-1,2:end-1] \ dstress[2:end-1]
        dstrain[2:end-1] .+= dstr
        if norm(dstr) < norm_acc
            converged = true
            break
        end
    end
    converged || error("No convergence in strain increment")
    return nothing
end

"""
    stress_driven_uniaxial_increment!(material, dstress11, dt;
                                      dstrain=[dstress11/200e3, -0.3*dstress11/200e3, -0.3*dstress11/200e3, 0.0, 0.0, 0.0],
                                      max_iter=50, norm_acc=1e-9)

Find a compatible strain increment for `material`.

The material state (`material.variables`) and the component 11 of the *stress*
increment are taken as prescribed. This routine computes a strain increment such
that the stress state predicted by integrating the material for one timestep
matches the one stored in `materials.variables.stress`. The computation starts
from the initial guess `dstrain`.

To converge quickly, the update takes advantage of the jacobian ∂σij/∂εkl
(`material.variables_new.jacobian`) provided by the material implementation.

This process is iterated at most `max_iter` times, until the non-prescribed
components of `dstrain` converge to within `norm_acc` (in a vector norm
sense).

If `max_iter` is reached and `dstrain` has not converged, `ErrorException` is
thrown.

Note the timestep is **not** committed; we call `integrate_material!`, but not
`update_material!`. Only `material.variables_new` is updated.
"""
function stress_driven_uniaxial_increment!(material, dstress11, dt;
                                           dstrain=[dstress11/200e3, -0.3*dstress11/200e3, -0.3*dstress11/200e3, 0.0, 0.0, 0.0],
                                           max_iter=50, norm_acc=1e-9)
    converged = false
    stress0 = tovoigt(material.variables.stress)
    for i=1:max_iter
        material.ddrivers.time = dt
        material.ddrivers.strain = fromvoigt(Symm2{Float64}, dstrain; offdiagscale=2.0)
        integrate_material!(material)
        stress = tovoigt(material.variables_new.stress)
        dstress = stress - stress0
        r = dstress
        r[1] -= dstress11
        D = tovoigt(material.variables_new.jacobian)
        dstr = -D \ r
        dstrain .+= dstr
        if norm(dstr) < norm_acc
            converged = true
            break
        end
    end
    converged || error("No convergence in strain increment")
    return nothing
end
