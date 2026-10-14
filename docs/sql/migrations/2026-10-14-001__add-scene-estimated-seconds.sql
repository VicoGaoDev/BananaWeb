ALTER TABLE external_api_scene_bindings
  ADD COLUMN estimated_seconds INT NOT NULL DEFAULT 60 AFTER credit_cost;
