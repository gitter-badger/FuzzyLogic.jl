ENV["GKSwstype"] = "100"

const IS_CI = get(ENV, "CI", "false") == "true"

import Pkg

if !IS_CI
    Pkg.activate(@__DIR__)
    Pkg.instantiate()
end

Pkg.add(Pkg.PackageSpec(name = "Documenter", rev = "30baed5")) # TODO remove once Documenter 0.28 is released

using Documenter
using DocThemeIndigo
using InteractiveUtils
using FuzzyLogic
using Literate

###############################
# GENERATE LITERATE NOTEBOOKS #
###############################

const jldir = joinpath(@__DIR__, "src", "literate") # input directory for literate scripts.
const mddir = joinpath(@__DIR__, "src") # output directory for markdown files.
const nbdir = joinpath(@__DIR__, "src", "notebooks") # output directory for notebooks.

# fix edit links (only locally)
function fix_edit_link(content)
    replace(content,
            "EditURL = \"<unknown>" => "EditURL = \"https://github.com/lucaferranti/FuzzyLogic.jl/blob/main")
end

# Adds link from markdown to notebook.
# Points to local path locally and to nbviewer when deployed.
notebook_link(file) = content -> notebook_link(file, content)
function notebook_link(file, content)
    root = IS_CI ? "@__NBVIEWER_ROOT_URL__" :
           "https://nbviewer.org/github/lucaferranti/FuzzyLogic.jl/blob/gh-pages/dev"
    path = joinpath(root, "notebooks", replace(file, ".jl" => ".ipynb"))
    note = """!!! tip "Try it yourself!"\n    Read this as Jupyter notebook [here]($path)"""
    replace(content, "DOWNLOAD_NOTE" => note)
end

for (root, _, files) in walkdir(jldir), file in files
    endswith(file, ".jl") || continue
    ipath = joinpath(root, file)
    opath = splitdir(replace(ipath, jldir => mddir))[1]
    Literate.markdown(ipath, opath;
                      preprocess = notebook_link(file),
                      postprocess = IS_CI ? identity : fix_edit_link,
                      credit = false)

    Literate.notebook(ipath, nbdir; execute = IS_CI, credit = false)
end

###################
# CREATE API DOCS #
###################

function generate_memberships()
    mfs = subtypes(FuzzyLogic.AbstractMembershipFunction)
    open(joinpath(@__DIR__, "src", "api", "memberships.md"), "w") do f
        write(f, """```@setup memberships
        using FuzzyLogic
        using Plots
        ```

        # Membership functions

        """)
        for mf in mfs
            sec = string(mf)[1:(end - 2)] * " membership function"
            write(f, """## $sec

            ```@docs
            $mf
            ```

            """)
            docstring = match(r"```julia\nmf = (\w+\(.+\))\n```", string(Docs.doc(mf)))
            if !isnothing(docstring)
                mfex = only(docstring.captures)
                write(f, """
                ```@example memberships
                plot($mfex, 0, 10) # hide
                ```

                """)
            end
        end
    end
end

generate_memberships()

###############
# CREATE HTML #
###############

makedocs(;
         modules = [FuzzyLogic], authors = "Luca Ferranti",
         sitename = "FuzzyLogic.jl",
         doctest = false, checkdocs = :exports, strict = true,
         format = Documenter.HTML(;
                                  assets = [DocThemeIndigo.install(FuzzyLogic)],
                                  prettyurls = IS_CI, collapselevel = 1,
                                  canonical = "https://lucaferranti.github.io/FuzzyLogic.jl"),
         pages = [
             "Home" => "index.md",
             "Tutorials" => [
                 "Build a Mamdani inference system" => "tutorials/mamdani.md",
                 "Build a Sugeno inference system" => "tutorials/sugeno.md",
             ],
             "Applications" => [
                 "Edge detection" => "applications/edge_detector.md",
             ],
             "API" => [
                 "Inference system API" => [
                     "Types" => "api/fis.md",
                     "Logical connectives" => "api/logical.md",
                     "Aggregation methods" => "api/aggregation.md",
                     "Defuzzification methods" => "api/defuzzification.md",
                 ],
                 "Membership functions" => "api/memberships.md",
                 "Reading/Writing" => "api/readwrite.md",
             ],
             "Contributor's Guide" => "contributing.md",
             "Release notes" => "changelog.md",
         ])

##########
# DEPLOY #
##########

if IS_CI
    deploydocs(; repo = "github.com/lucaferranti/FuzzyLogic.jl", push_preview = true)
end
