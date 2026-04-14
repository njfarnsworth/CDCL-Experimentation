using Statistics
x, y = dicts_to_vectors(incidence_dict, activity_dict)
println("Pearson correlation = ", cor(x,y))