import os
import yaml
import torch

from datasets import load_from_disk

from transformers import (
    
    AutoModelForCausalLM,
    AutoTokenizer,
    
    Trainer,
    TrainingArguments,
    
    default_data_collator
    
)

from peft import (
    
    get_peft_model,
    LoraConfig,
    
    TaskType,
    prepare_model_for_kbit_training
)

from typing import Dict

def load_config(config_path: str) -> Dict:
    
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)

def setup_model_and_tokenizer():
    
    model_config = load_config('../../config/models/llama2.yaml')
    
    model_id = os.environ['MODEL_NAME']
    peft_method = os.environ['PEFT_METHOD']
    
    batch_size = int(os.environ['BATCH_SIZE'])
    
    tokenizer = AutoTokenizer.from_pretrained(
        
        model_id,
        trust_remote_code=True,
        use_fast=True
    )
    
    if not tokenizer.pad_token_id:
        tokenizer.pad_token_id = tokenizer.eos_token_id
    
    #Load model with quantization if specified
    quantization = model_config['model']['quantization']
    
    model_kwargs = {
        "trust_remote_code": True,
        "torch_dtype": torch.float16,
    }
    
    if quantization == "4bit":
        
        model_kwargs.update({
            
            "load_in_4bit": True,
            "quantization_config": {
                "bnb_4bit_compute_dtype": torch.float16,
                "bnb_4bit_quant_type": "nf4",
                "bnb_4bit_use_double_quant": True,
            }
        })
        
    elif quantization == "8bit":
        model_kwargs["load_in_8bit"] = True
        
    model = AutoModelForCausalLM.from_pretrained(model_id, **model_kwargs)
    
    #Prepare model for k-bit training if using quantization
    
    if quantization in ["4bit", "8bit"]:
        model = prepare_model_for_kbit_training(model)
    
    #Configure PEFT
    
    if peft_method == "lora":
        
        lora_config = LoraConfig(
            
            r = model_config['training']['lora_config']['r'],
            lora_alpha = model_config['training']['lora_config']['alpha'],
            
            target_modules = model_config['training']['lora_config']['target_modules'],
            lora_dropout = model_config['training']['lora_config']['dropout'],
            
            bias = "none",
            task_type = TaskType.CAUSAL_LM
            
        )
        
        model = get_peft_model(model, lora_config)
        
    return model, tokenizer

def train():
   
    model_config = load_config('../../config/models/llama2.yaml')
    dataset_config = load_config('../../config/datasets/alpaca.yaml')
    
    #Setup model and tokenizer
    model, tokenizer = setup_model_and_tokenizer()
    
    #Load tokenized dataset
    dataset_path = dataset_config['storage']['output_path']
    tokenized_dataset = load_from_disk(dataset_path)
    
    #Training arguments
    training_args = TrainingArguments(
        
        output_dir = dataset_config['storage']['checkpoint_path'],
        per_device_train_batch_size = model_config['training']['batch_size'],
        
        gradient_accumulation_steps = model_config['training']['gradient_accumulation_steps'],
        learning_rate = float(model_config['training']['learning_rate']),
        warmup_steps = model_config['training']['warmup_steps'],
        
        max_steps = model_config['training']['max_steps'],
        save_steps = model_config['training']['save_steps'],
        eval_steps = model_config['training']['eval_steps'],
        
        logging_steps = 10,
        fp16 = True,
        
        optim = "paged_adamw_32bit",
        lr_scheduler_type = "cosine",
        
        evaluation_strategy = "steps",
        save_strategy = "steps",
        
        load_best_model_at_end = True,
    )
    
    #Initialize trainer
    trainer = Trainer(
        
        model=model,
        args=training_args,
        
        train_dataset=tokenized_dataset["train"],
        eval_dataset=tokenized_dataset.get("validation"),
        
        tokenizer=tokenizer,
        data_collator=default_data_collator,
        
    )
    
    trainer.train()
    
    trainer.save_model()
    
    print(f"Model saved to {training_args.output_dir}")

if __name__ == "__main__":
    train() 