local ffi = require("ffi")
local uv = vim.loop

ffi.cdef([[
 int getuid(void);
]])

local M = {}

local default_config = {
	load = { ".nvim" },
}

local config = {}

local function file_owned_by_me(file)
	uv.fs_open(file, "r", 438, function(err, fd)
		assert(not err, err)
		uv.fs_fstat(fd, function(err, stat)
			assert(not err, err)
			uv.fs_close(fd, function(err)
				assert(not err, err)
				-- print(ffi.C.getuid(), type(ffi.C.getuid()), stat.uid, type(stat.uid), ffi.C.getuid() == stat.uid)
				if ffi.C.getuid() == stat.uid then
          vim.defer_fn(function ()
            vim.cmd([[luafile ]] .. file)
            print("loaded " .. file)
          end, 1)
				end
			end)
		end)
	end)
end

local function load_file(path)
	if file_owned_by_me(path) then
		-- vim.cmd([[luafile ]] .. path)
		-- print("loaded " .. path)
		return true
	else
		-- print(path .. " exists but is not loaded. Security reason: a diffent owner.")
	end
	return false
end

local home = vim.fn.expand("$HOME")

function M.load(files)
	local cwd = vim.fn.getcwd()
	for _, file in pairs(files) do
		local dirpath = cwd .. "/"
		local filepath
		while vim.loop.fs_realpath(dirpath) ~= home do
			filepath = dirpath .. file
			if vim.loop.fs_stat(filepath) then
				load_file(filepath)
				break
			else
				dirpath = dirpath .. "../"
			end
		end
	end
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", {}, default_config, opts or {})
	if config.load then
		vim.api.nvim_create_autocmd("VimEnter", {
			callback = function()
				M.load(config.load)
			end,
		})
	end
end

return M
