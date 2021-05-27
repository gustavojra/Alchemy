using Colors
import Base: delete!

export Atom
export Bond
export Ensamble

include("Constants.jl")

struct Atom 
    center::Point3f0
    symbol::String
    plot::AbstractPlot
end

struct Bond
    atom1::Atom
    atom2::Atom
    plot::Arrows
    Bond(A1, A2, p) = A1 != A2 ? new(A1, A2, p) : error("Cannot create a bound withina single atom")
end

struct Ensamble 
    scene::Scene
    atoms::Vector{Atom}
    bonds::Vector{Bond}
end

function Atom(E::Ensamble, S::String, x::T, y::T, z::T) where T <: Number
    r = get_atom_radius(S)
    center = Point3f0(x,y,z)
    sphere = Sphere(center, r)
    plot = mesh!(E.scene, sphere, show_axis=false, color=atom_color[S])
    A = Atom(center, S, plot)
    push!(E.atoms, A)
    return A
end

function Bond(E::Ensamble, i::Int, j::Int)
    A1, A2 = E.atoms[i], E.atoms[j]
    xyz = [A1.center]
    uvw = [A2.center - A1.center]
    plot = arrows!(E.scene, xyz, uvw, linewidth=0.1, arrowsize=0.0, linecolor=stegeman)
    B = Bond(E.atoms[i], E.atoms[j], plot)
    push!(E.bonds, B)
    return B
end


function Ensamble()
    s = Scene()
    atoms=Vector{Atom}()
    bonds=Vector{Bond}()
    Ensamble(s,atoms,bonds)
end

function Ensamble(filename::String)
    E = Ensamble()
    read_xyz_to!(E, filename)
    find_bonds!(E)
    return E
end

function read_xyz_to!(E::Ensamble, filename)
    for l = eachline(filename)
        m = match(XYZ_REGEX, l)
        if m !== nothing
            S = String(m.captures[1])
            xyz = m.captures[2:end]
            @assert length(xyz) == 3
            xyz = parse.(Float32, xyz)
            Atom(E, S, xyz...)
        end
    end
end

function find_bonds!(E::Ensamble)

    for i in eachindex(E.atoms)
        r1 = E.atoms[i].center
        for j in (i+1):length(E.atoms)
            r2 = E.atoms[j].center
            d = √sum((r1 .- r2).^2)
            if d < 1.55
                Bond(E, i, j)
            end
        end
    end
end

function delete!(E::Ensamble, A::Atom)

    # Remove atom from ensamble
    filter!(a -> a != A, E.atoms)

    # Delete any bonds involving the atom
    let to_be_deleted = Vector{Bond}()
        # Mark atoms for deletion
        for B in E.bonds
             if A in (B.atom1, B.atom2)
                 push!(to_be_deleted, B)
             end
        end
        # Delete them
        for B in to_be_deleted
            delete!(E, B)
        end
    end

    scene = E.scene
    plot = A.plot
    # Copied from Makie.jl source
    len = length(scene.plots)
    filter!(x -> x !== plot, scene.plots)
    if length(scene.plots) == len
        error("$(typeof(plot)) not in scene!")
    end
    for screen in scene.current_screens
        delete!(screen, scene, plot)
    end
end

function delete!(E::Ensamble, B::Bond)
    # Remove Bond from ensamble
    filter!(b -> b != B, E.bonds)

    scene = E.scene
    plot = B.plot

    # Copied from Makie.jl source
    len = length(scene.plots)
    filter!(x -> x !== plot, scene.plots)
    if length(scene.plots) == len
        error("$(typeof(plot)) not in scene!")
    end
    for screen in scene.current_screens
        delete!(screen, scene, plot)
    end
end