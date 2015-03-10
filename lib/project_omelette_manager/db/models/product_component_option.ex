#
# == product_component_option.ex
#
# This module contains the db schema the 'product_component' table
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2014 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
defmodule ProjectOmeletteManager.DB.Models.ProductComponentOption do
  @required_fields [:product_component_id, :name]
  @optional_fields [:value]
  @member_of_fields []
  use ProjectOmeletteManager.DB.Models.BaseModel

  alias ProjectOmeletteManager.DB.Models.ProductComponent

  schema "product_component_options" do
    belongs_to :product_component,     ProductComponent
    field :name,                       :string
    field :value,                      :string    
    timestamps
  end
end