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

    vim.diagnostic.reset(ns, bufnr)
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

  local mock_linter_json = {
    fn = function()
      return vim.json.encode({
        source = 'mock_linter_json',
        bufnr = bufnr,
        col = 1,
        end_col = 9,
        lnum = 1,
        end_lnum = 0,
        message = 'Very important error message',
        namespace = ns,
        severity = 'warning',
      })
    end,
    parse = lint.from_json({
      get_diagnostics = function(...)
        return { vim.json.decode(...) }
      end,
      attributes = {
        lnum = 'lnum',
        end_lnum = 'end_lnum',
        col = 'col',
        end_col = 'end_col',
        message = 'message',
        code = 'severity',
      },
      source = 'mock_linter_json',
    }),
  }

  it('can lint with single linter', function()
    if true then
      return
    end
    ft('lua'):lint(mock_linter_regex)

    gapi.lint()
    vim.wait(100)

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

  it('can lint with multiple linters', function()
    if true then
      return
    end
    ft('lua'):lint(mock_linter_regex):append(mock_linter_json)

    gapi.lint()
    vim.wait(100)

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
      {
        bufnr = bufnr,
        col = 0,
        end_col = 0,
        end_lnum = 0,
        lnum = 0,
        message = 'Very important error message[warning]',
        namespace = ns,
        severity = 2,
        source = 'mock_linter_json',
      },
    }, vim.diagnostic.get())
  end)

  it('can define a linter for all filetypes', function()
    ft('*'):lint({
      fn = function()
        return 'some stuff'
      end,
      parse = function()
        return {
          {
            bufnr = bufnr,
            col = 1,
            end_col = 1,
            lnum = 1,
            end_lnum = 1,
            message = 'foo',
            namespace = 42,
            severity = vim.diagnostic.severity.HINT,
            source = 'bar',
          },
        }
      end,
    })

    gapi.lint()
    vim.wait(100)

    same({
      {
        bufnr = bufnr,
        col = 1,
        end_col = 1,
        lnum = 1,
        end_lnum = 1,
        message = 'foo',
        namespace = api.nvim_get_namespaces().Guard,
        severity = vim.diagnostic.severity.HINT,
        source = 'bar',
      },
    }, vim.diagnostic.get())
  end)
end)
