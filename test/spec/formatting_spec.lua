local stub = require("luassert.stub")
local a = require("plenary.async_lib")

local u = require("null-ls.utils")
local c = require("null-ls.config")
local methods = require("null-ls.methods")
local generators = require("null-ls.generators")

local method = methods.lsp.FORMATTING

describe("formatting", function()
    stub(vim.lsp.util, "apply_text_edits")
    stub(vim.api, "nvim_buf_get_option")
    stub(vim.api, "nvim_get_current_buf")
    stub(vim, "cmd")
    stub(a, "await")

    stub(u, "make_params")
    stub(generators, "run")

    local mock_bufnr = 65
    local mock_params
    before_each(function()
        mock_params = {key = "val"}

        vim.api.nvim_buf_get_option.returns(nil)
        vim.api.nvim_get_current_buf.returns(nil)
    end)

    after_each(function()
        vim.lsp.util.apply_text_edits:clear()
        vim.api.nvim_buf_get_option:clear()
        vim.api.nvim_get_current_buf:clear()
        vim.cmd:clear()
        a.await:clear()

        u.make_params:clear()
        generators.run:clear()

        c.reset()
    end)

    local formatting = require("null-ls.formatting")

    describe("handler", function()
        it("should not set handled flag if method does not match", function()
            formatting.handler("otherMethod", mock_params, nil, mock_bufnr)

            assert.equals(mock_params._null_ls_handled, nil)
        end)

        it("should set handled flag if method matches", function()
            formatting.handler(method, mock_params, nil, mock_bufnr)

            assert.equals(mock_params._null_ls_handled, true)
        end)

        it("should assign bufnr to params", function()
            formatting.handler(method, mock_params, nil, mock_bufnr)

            assert.equals(mock_params.bufnr, mock_bufnr)
        end)
    end)

    describe("apply_edits", function()
        it("should call make_params with params and internal method", function()
            formatting.handler(methods.lsp.FORMATTING, mock_params, nil,
                               mock_bufnr)

            assert.same(u.make_params.calls[1].refs[1], mock_params)
            assert.equals(u.make_params.calls[1].refs[2],
                          methods.internal.FORMATTING)
        end)

        it("should return if buffer is modified", function()
            vim.api.nvim_buf_get_option.returns(true)

            formatting.handler(methods.lsp.FORMATTING, mock_params, nil,
                               mock_bufnr)

            assert.stub(vim.lsp.util.apply_text_edits).was_not_called()
        end)

        it("should call apply_text_edits with edits", function()
            a.await.returns("edits")

            formatting.handler(methods.lsp.FORMATTING, mock_params, nil,
                               mock_bufnr)

            assert.stub(vim.lsp.util.apply_text_edits).was_called_with("edits",
                                                                       mock_bufnr)
            assert.stub(vim.cmd).was_not_called()
        end)

        it("should save buffer if config option is set and buffer is current",
           function()
            c.setup({save_after_format = true})
            vim.api.nvim_get_current_buf.returns(mock_bufnr)

            formatting.handler(methods.lsp.FORMATTING, mock_params, nil,
                               mock_bufnr)

            assert.stub(vim.cmd).was_called_with("silent noautocmd :update")
        end)

        describe("postprocess", function()
            local edit = {row = 1, col = 5, text = "something bad"}
            local postprocess
            before_each(function()
                formatting.handler(methods.lsp.FORMATTING, mock_params, nil,
                                   mock_bufnr)
                postprocess = generators.run.calls[1].refs[2]
            end)

            it("should convert range", function()
                postprocess(edit)

                assert.same(edit.range.start, {character = 5, line = 1})
                assert.same(edit.range["end"], {character = -1, line = 1})
            end)

            it("should assign edit newText", function()
                postprocess(edit)

                assert.equals(edit.newText, edit.text)
            end)
        end)
    end)
end)
