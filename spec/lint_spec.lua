---@diagnostic disable: undefined-field, undefined-global
local api = vim.api
local same = assert.are.same
local ft = require('guard.filetype')
local lint = require('guard.lint')
local gapi = require('guard.api')
local ns = api.nvim_get_namespaces()['Guard']

describe('lint module', function()
  local bufnr
  before_each(function()
    for k, _ in pairs(ft) do
      ft[k] = nil
    end

    bufnr = api.nvim_create_buf(true, false)
    vim.bo[bufnr].filetype = 'lua'
    api.nvim_set_current_buf(bufnr)
    vim.cmd('silent! write! /tmp/lint_spec_test.lua')
  end)

  local mock_linter_regex = {
    fn = function()
      return '/tmp/lint_spec_test.lua:1:1: warning: Very important error message [error code 114514]'
    end,
    parse = lint.from_regex({
      source = 'mock_linter_regex',
      regex = ':(%d+):(%d+):%s+(%w+):%s+(.-)%s+%[(.-)%]',
      groups = { 'lnum', 'col', 'severity', 'message', 'code' },
      offset = 0,
      severities = {
        information = lint.severities.info,
        hint = lint.severities.info,
        note = lint.severities.style,
      },
    }),
  }

  local mock_linter_json = {}

  it('can lint with single linter', function()
    ft('lua'):lint(mock_linter_regex)

    gapi.lint()
    vim.wait(1000)

    same({
      {
        source = 'mock_linter_regex',
        bufnr = bufnr,
        col = 1,
        end_col = 1,
        lnum = 1,
        end_lnum = 1,
        message = 'Very important error message[error code 114514]',
        namespace = ns,
        severity = 2,
      },
    }, vim.diagnostic.get())
  end)
end)
