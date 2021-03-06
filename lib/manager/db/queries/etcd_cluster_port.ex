defmodule OpenAperture.Manager.DB.Queries.EtcdClusterPort do
  import Ecto.Query

  alias OpenAperture.Manager.DB.Models.EtcdClusterPort

  @doc """
  Retrieves the DB.Models.EtcdClusterPorts for a cluster token

  If no record is found, returns nil.
  """
  @spec get_ports_by_cluster(term) :: term
  def get_ports_by_cluster(cluster_id) do
    from ecp in EtcdClusterPort,
      where: ecp.etcd_cluster_id == ^cluster_id,
      select: ecp
  end 

  @doc """
  Method to retrieve the DB.Models.EtcdClusterPorts for a component id

  ## Options

  The `product_id` option is the integer identifier of the product
      
  ## Return values
   
  db query
  """
  @spec get_ports_by_component(term) :: term
  def get_ports_by_component(component_id) do
    from ecp in EtcdClusterPort,
      where: ecp.product_component_id == ^component_id,
      select: ecp
  end
end