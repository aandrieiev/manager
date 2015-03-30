#
# == workflow_controller.ex
#
# This module contains the controller for managing Workflows
#
require Logger

defmodule ProjectOmeletteManager.Web.Controllers.WorkflowController do
  use ProjectOmeletteManager.Web, :controller

  require Repo

  alias ProjectOmeletteManager.Controllers.FormatHelper
  alias ProjectOmeletteManager.DB.Models.Workflow, as: WorkflowDB
  alias ProjectOmeletteManager.DB.Queries.Workflow, as: WorkflowQuery

  plug :action

  @moduledoc """
  This module contains the controller for managing Workflows
  """  

  @workflow_sendable_fields [
    :id, 
    :deployment_repo, 
    :deployment_repo_git_ref, 
    :source_repo,
    :source_repo_git_ref,
    :source_commit_hash, 
    :milestones,         
    :current_step,       
    :elapsed_step_time,  
    :elapsed_workflow_time,
    :workflow_duration,    
    :workflow_step_durations,
    :workflow_error,         
    :workflow_completed,     
    :event_log,
    :inserted_at, 
    :updated_at
  ]

  @doc """
  GET /workflows - Retrieve all Workflows for a lookback period
    * Query Parameters:  
      * lookback - integer, defaults to 24 (specify 0 for all)
      * deployment_repo - string containing the deployment repo
      * source_repo - string containing the source repo

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec index(term, [any]) :: term
  def index(conn, params) do
    lookback = if params["lookback"] != nil do
      {int, _} = Integer.parse(params["lookback"])
      int
    else
      24
    end

    deployment_repo = cond do
      params["deployment_repo"] != nil -> params["deployment_repo"]
      params["source_repo"] != nil     -> "#{params["source_repo"]}_docker"
      true -> nil
    end

    raw_workflows = cond do
    deployment_repo != nil && String.length(deployment_repo) > 0 ->
      Repo.all(WorkflowQuery.get_workflows_by_deployment_repo(deployment_repo, lookback))
    true ->
      Repo.all(WorkflowQuery.get_workflows(lookback))
    end

    json conn, convert_raw_workflows(raw_workflows)
 end

  @doc """
  GET /workflowss/:id

  Retrieve a specific Workflow

  ## Options

  The `conn` option defines the underlying HTTP connection.

  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection.
  """
  @spec show(term, Map) :: term
  def show(conn, %{"id" => id} = _params) do
    case get_workflow(id) do
      nil -> resp(conn, :not_found, "")
      raw_workflow -> json conn, List.first(convert_raw_workflows([raw_workflow]))      
    end
  end

  @doc """
  POST /workflows - Create a Workflow

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec create(term, [any]) :: term
  def create(conn, params) do
    id = "#{UUID.uuid1()}"
    raw_workflow_id = string_to_uuid(id)

    changeset = WorkflowDB.new(%{
      :id => raw_workflow_id,
      :deployment_repo => params["deployment_repo"],
      :deployment_repo_git_ref => params["deployment_repo_git_ref"],
      :source_repo => params["source_repo"],
      :source_repo_git_ref => params["source_repo_git_ref"],
      :source_commit_hash => params["source_commit_hash"],
      :milestones => params["milestones"],
      :current_step => params["current_step"],
      :elapsed_step_time => params["elapsed_step_time"],
      :elapsed_workflow_time => params["elapsed_workflow_time"],
      :workflow_duration => params["workflow_duration"],
      :workflow_step_durations => params["workflow_step_durations"],
      :workflow_error => params["workflow_error"],
      :workflow_completed => params["workflow_completed"],
      :event_log => params["event_log"],
    })

    if changeset.valid? do
      try do
        raw_workflow = Repo.insert(changeset)
        path = ProjectOmeletteManager.Router.Helpers.workflow_path(Endpoint, :show, id)

        # Set location header
        conn
        |> put_resp_header("location", path)
        |> resp(:created, "")
      rescue
        e ->
          Logger.error("Error inserting Workflow record: #{inspect e}")
          resp(conn, :internal_server_error, "")
      end
    else
      conn
      |> put_status(:bad_request)
      |> json FormatHelper.keywords_to_map(changeset.errors)
    end
  end

  @doc """
  PUT/PATCH /workflows/:id - Update a Workflow

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec update(term, [any]) :: term
  def update(conn, %{"id" => id} = params) do
    raw_workflow_id = string_to_uuid(id)
    raw_workflow = get_workflow(id)
    if raw_workflow == nil do
      resp(conn, :not_found, "")
    else
      workflow_params = Map.put(params, "id", raw_workflow_id)
      changeset = WorkflowDB.update(raw_workflow, workflow_params)
      if changeset.valid? do
        try do
          Repo.update(changeset)
          path = ProjectOmeletteManager.Router.Helpers.workflow_path(Endpoint, :show, id)
          conn
          |> put_resp_header("location", path)
          |> resp(:no_content, "")
        rescue
          e ->
            Logger.error("Error updating Workflow record: #{inspect e}")
            resp(conn, :internal_server_error, "")
        end
      else
        conn
        |> put_status(:bad_request)
        |> json FormatHelper.keywords_to_map(changeset.errors)
      end
    end
  end

  @doc """
  DELETE /workflows/:id - Delete a Workflow

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec destroy(term, [any]) :: term
  def destroy(conn, %{"id" => id} = _params) do
    case get_workflow(id) do
      nil -> resp(conn, :not_found, "")
      workflow ->
        Repo.transaction(fn ->
          Repo.delete(workflow)
        end)
        resp(conn, :no_content, "")
    end
  end  

  @doc false
  # Method to convert an array of DB.Models.Workflows into an array of List of workflows
  #
  # Options
  #
  # The `raw_workflows` option defines the array of structs of the DB.Models.Workflows to be parsed
  #
  ## Return Values
  #
  # List of parsed product plans
  #
  def convert_raw_workflows(raw_workflows) do
    case raw_workflows do
      nil -> []
      [] -> []
      _ ->
        Enum.reduce raw_workflows, [], fn(raw_workflow, workflows) -> 
          uuid = uuid_to_string(raw_workflow.id)

          workflow = FormatHelper.to_sendable(raw_workflow, @workflow_sendable_fields)
          if (workflow != nil) do
            if (workflow[:id] != nil) do
              workflow = Map.put(workflow, :id, uuid)
            end

            if (workflow[:inserted_at] != nil) do
              workflow = Map.put(workflow, :inserted_at, "#{:httpd_util.rfc1123_date(ecto_to_erl(workflow[:inserted_at]))}")
            end

            if (workflow[:updated_at] != nil) do
              workflow = Map.put(workflow, :updated_at, "#{:httpd_util.rfc1123_date(ecto_to_erl(workflow[:updated_at]))}")
            end
        
            workflows = workflows ++ [workflow]
          end

          workflows
        end
    end
  end

  @doc false
  # Method to convert a binary UUID into a String
  # Based on https://github.com/zyro/elixir-uuid/blob/master/lib/uuid.ex#L246
  #
  ## Options
  # The option represents a binary UUID
  #
  ## Return Value
  #
  # String representing the UUID
  #
  @spec uuid_to_string(term) :: term
  defp uuid_to_string(<<u0::32, u1::16, u2::16, u3::16, u4::48>>) do
    try do
      :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b",
                     [u0, u1, u2, u3, u4])
        |> to_string
    rescue _ ->
      ""
    end
  end

  @doc false
  # Method to convert a String into a binary UUID
  #
  ## Options
  # The option represents a binary UUID
  #
  ## Return Value
  #
  # String representing the UUID
  #
  @spec string_to_uuid(String.t()) :: term
  defp string_to_uuid(id) do
    try do
      (id |> UUID.info)[:binary]
    rescue _ ->
      nil
    end
  end

  @doc false
  # Method to get a Workflow based on a String UUID
  #
  ## Options
  # The option represents a String UUID
  #
  ## Return Value
  #
  # Workflow
  #
  @spec get_workflow(String.t()) :: term
  defp get_workflow(id) do
    cond do 
      id == nil || String.length(id) == 0 -> nil
      true ->
        case string_to_uuid(id) do
          nil -> nil
          raw_id -> Repo.get(WorkflowDB, raw_id)
        end
    end
  end

  @doc false
  # Method to convert an Ecto.DateTime into an erlang calendar
  # Based on https://github.com/elixir-lang/ecto/blob/v0.2.6/lib/ecto/types.ex#L46
  #
  ## Options
  # The option represents an ecto DateTime
  #
  ## Return Value
  #
  # erlang calendar
  #
  @spec ecto_to_erl(term) :: term
  defp ecto_to_erl(%Ecto.DateTime{year: year, month: month, day: day, hour: hour, min: min, sec: sec}) do
    {{year, month, day}, {hour, min, sec}}
  end 
end