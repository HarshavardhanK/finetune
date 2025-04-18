import os
import yaml
import torch

from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer

def load_config(config_path: str) -> dict:
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)

def merge_lora_weights():
    #Load configurations
    model_config = load_config('../../config/models/llama2.yaml')
    dataset_config = load_config('../../config/datasets/alpaca.yaml')
    
    
    model_id = os.environ['MODEL_NAME']
    checkpoint_path = dataset_config['storage']['checkpoint_path']
    output_path = os.path.join(checkpoint_path, "final_model_output")
    
    print(f"Loading base model: {model_id}")
    
    #Load base model
    
    model = AutoModelForCausalLM.from_pretrained(
        model_id,
        torch_dtype=torch.float16,
        trust_remote_code=True
    )
    
    print("Loading LoRA weights")
    
    #Load LoRA model
    model = PeftModel.from_pretrained(
        model,
        checkpoint_path,
        torch_dtype=torch.float16
    )
    
    #Merge weights
    print("Merging weights")
    
    
    model = model.merge_and_unload()
    
    print(f"Saving merged model to: {output_path}")
    
    #Save merged model
    
    model.save_pretrained(
        output_path,
        safe_serialization=True
    )
    
    #Save tokenizer
    
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    tokenizer.save_pretrained(output_path)
    
    print("Model merging completed successfully!")

if __name__ == "__main__":
    merge_lora_weights() 