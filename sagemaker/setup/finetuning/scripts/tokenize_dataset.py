import os
import yaml
import torch

from datasets import load_dataset
from transformers import AutoTokenizer

from typing import Dict, List

def load_config(config_path: str) -> Dict:
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)

def format_instruction(example: Dict, template: str) -> str:
    """Format the instruction using the template from config."""
    return template.format(
        instruction=example.get('instruction', ''),
        input=example.get('input', ''),
        output=example.get('output', '')
    )

def tokenize_dataset():

    model_name = os.environ['MODEL_NAME']
    dataset_path = os.environ['DATASET_PATH']
    max_length = int(os.environ['MAX_LENGTH'])
    
    dataset_config = load_config('../../config/datasets/alpaca.yaml')
    
    tokenizer = AutoTokenizer.from_pretrained(
        model_name,
        use_fast=True,
        padding_side="right",
        trust_remote_code=True
    )
    
    if not tokenizer.pad_token_id:
        tokenizer.pad_token_id = tokenizer.eos_token_id
    
    dataset = load_dataset(dataset_path)
    
    #Get prompt template from config
    prompt_template = dataset_config['dataset']['preprocessing']['prompt_template']
    
    def preprocess_function(examples: Dict) -> Dict:
        
        #Format instructions using template
        
        texts = [format_instruction(
            {'instruction': instr, 'input': inp, 'output': out},
            
            prompt_template
            
        ) for instr, inp, out in zip(
            
            examples['instruction'],
            examples.get('input', [''] * len(examples['instruction'])),
            examples['output']
            
        )]
        
        tokenized = tokenizer(
            texts,
            truncation=True,
            max_length=max_length,
            padding="max_length",
            return_tensors="pt"
        )
        
        #Create attention masks and labels
        tokenized['labels'] = tokenized['input_ids'].clone()
        tokenized['attention_mask'] = torch.ones_like(tokenized['input_ids'])
        
        return tokenized
    
    #Process dataset
    tokenized_dataset = dataset.map(
        preprocess_function,
        batched=True,
        remove_columns=dataset['train'].column_names
    )
    
    
    output_path = dataset_config['storage']['output_path']
    tokenized_dataset.save_to_disk(output_path)
    
    print(f"Tokenized dataset saved to {output_path}")

if __name__ == "__main__":
    tokenize_dataset() 