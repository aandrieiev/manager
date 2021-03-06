defmodule OpenAperture.Manager.DB.Models.ProductDeployment do
  @required_fields [:product_id, :product_deployment_plan_id]
  @optional_fields [:execution_options, :completed, :duration, :output]
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models

  schema "product_deployments" do
    belongs_to :product,                  Models.Product
    belongs_to :product_deployment_plan,  Models.ProductDeploymentPlan
    belongs_to :product_environment,      Models.ProductEnvironment
    has_many   :product_deployment_steps, Models.ProductDeploymentStep
    field :execution_options,             :string
    field :completed,                     :boolean
    field :duration,                      :string
    field :output,                        :string
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end

  def destroy_for_product(product), do: destroy_for_association(product, :deployments)

  def destroy(pd) do
    Repo.transaction(fn ->
      Models.ProductDeploymentStep.destroy_for_deployment(pd)
      Repo.delete(pd)
    end)
    |> transaction_return
  end
  
end