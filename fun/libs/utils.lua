local log = require("fun.libs.log")

local logger = log.get_logger("fun.utils")

--- @class fun.libs.utils
local M = {}

--- Load json from bundled resource
--- @param filepath string path to the json file
--- @return table|nil
function M.load_json(filepath)
	local resource, is_error = sys.load_resource(filepath)
	if is_error then
		logger:error("Error loading resource: " .. filepath)
		return nil
	end

	local ok, result = pcall(json.decode, resource)
	if not ok then
		logger:error("JSON decode error for: " .. filepath)
		return nil
	end

	return result
end

function M.gui_log_tree(root_node)
    local all_nodes = gui.get_tree(root_node)

    -- Step 1: Create a map of parent -> list of children
    local children_map = {}
    for _, node in pairs(all_nodes) do
        local parent = gui.get_parent(node)
        if parent then
			local parent_id = gui.get_id(parent)
            children_map[parent_id] = children_map[parent_id] or {}
            table.insert(children_map[parent_id], gui.get_id(node))
        end
    end

    -- Step 2: Recursively build the tree
    local function build_subtree(node_id)
        local subtree = {}
        local children = children_map[node_id] or {}
        for _, child_id in pairs(children) do
            subtree[child_id] = build_subtree(child_id)
        end
        return subtree
    end

    -- Step 3: Build the tree starting from the root
    local tree = {}
    tree[gui.get_id(root_node)] = build_subtree(gui.get_id(root_node))

    -- Step 4: Log the tree
    local function log_tree(subtree, indent)
        for child_id, child_subtree in pairs(subtree) do
            local node_id = child_id
            -- local node_type = gui.get_type(child)
            
            print(string.format("%s- %s", indent, node_id))
            
            log_tree(child_subtree, indent .. "  ")
        end
    end

    log_tree(tree[gui.get_id(root_node)], "")
end


return M