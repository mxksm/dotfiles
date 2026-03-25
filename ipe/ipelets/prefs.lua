-- Safely initialize both tables
if not prefs.initial_attributes then 
    prefs.initial_attributes = {} 
end
if not prefs.initial then
    prefs.initial = {}
end

-- Set the default alignments
prefs.initial_attributes.horizontalalignment = "hcenter"
prefs.initial_attributes.verticalalignment = "vcenter"

-- Set the default pen size to fat
prefs.initial_attributes.pen = "fat"

-- Set the default path mode to Stroke & Fill
prefs.initial_attributes.pathmode = "strokedfilled"

-- Set the default grid size (4 corresponds to 4pt)
prefs.initial.grid_size = 4
